import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'data/repositories/heart_rate_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/platform/android_display_service.dart';
import 'data/services/platform/desktop_overlay_service.dart';
import 'data/services/platform/macos_app_menu_service.dart';
import 'data/services/platform/macos_menubar_service.dart';
import 'data/services/platform/obs_overlay_service.dart';
import 'data/services/platform/overlay_ipc.dart';
import 'data/services/platform/windows_overlay_process_service.dart';
import 'data/services/simulated_heart_rate_source.dart';
import 'domain/models/heart_rate_scenario.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/overlay/views/android_overlay_page.dart';
import 'ui/features/overlay/views/desktop_overlay_page.dart';
import 'ui/features/overlay/views/overlay_process_page.dart';

/// 应用入口。
///
/// 三种身份共用同一个可执行文件:
/// 1. **主窗口**(各平台):正常启动主界面;
/// 2. **Windows 悬浮窗子进程**:由主进程以
///    `--overlay-process --overlay-port=<port>` 拉起,只渲染悬浮窗
///    (见 [OverlayProcessPage]);原因见 [WindowsOverlayProcessService]。
/// 3. **macOS 悬浮窗副窗口**:desktop_multi_window 以同一入口启动第二个引擎,
///    通过 [WindowController.arguments] 区分(macOS 进程内方案保持不变)。
///
/// 注意:Android 悬浮窗入口 [overlayMain] 也必须定义在 main.dart——
/// flutter_overlay_window 的 DartEntrypoint 只在根库中解析入口函数。
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 悬浮窗子进程:最先判定,避免进入主界面逻辑。
  final overlayPort = overlayProcessPort(args);
  if (overlayPort != null) {
    await _runOverlayProcess(overlayPort);
    return;
  }

  // macOS 悬浮窗副窗口(进程内第二个引擎)。
  if (Platform.isMacOS) {
    final controller = await WindowController.fromCurrentEngine();
    if (controller.arguments == DesktopOverlayService.overlayWindowArgument) {
      runApp(const _DesktopOverlayApp());
      return;
    }
  }
  await _runMainApp();
}

/// 连接主进程并渲染悬浮窗子进程界面。
Future<void> _runOverlayProcess(int port) async {
  final link = OverlayClientLink();
  runApp(_OverlayProcessApp(link: link, port: port));
}

Future<void> _runMainApp() async {
  // 主窗口桌面配置:默认尺寸、最小尺寸与窗口标题;隐藏原生标题栏,
  // 由主界面顶部栏承担拖拽与窗口控制(macOS 保留红绿灯)。
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1120, 760),
        minimumSize: Size(880, 620),
        center: true,
        title: 'PulseSight',
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final settings = SharedPreferencesSettingsRepository();
  // 启动时先恢复持久化的模拟场景,再构造数据源,
  // 使连接前的 UI 场景选择与实际生成参数一致。
  final stored = await settings.loadAll();
  final source = SimulatedHeartRateSource(
    scenario: HeartRateScenario.fromString(
      stored[SettingsKeys.simulatedScenario] as String?,
    ),
  );
  final repository = HeartRateRepository(source: source);

  final DesktopOverlay? desktopOverlay;
  // macOS 用进程内副窗口(稳定);Windows 用独立进程,规避 Flutter Windows
  // 嵌入层不支持单进程多引擎的限制(见 WindowsOverlayProcessService)。
  if (Platform.isMacOS) {
    desktopOverlay = DesktopOverlayService(repository: repository);
  } else if (Platform.isWindows) {
    desktopOverlay = WindowsOverlayProcessService(repository: repository);
  } else {
    desktopOverlay = null;
  }

  final MenubarDisplay? menubar;
  if (Platform.isMacOS) {
    menubar = MacosMenubarService(repository: repository);
  } else {
    menubar = null;
  }

  // 应用菜单(「显示」菜单的显示端开关条目),仅 macOS 有原生菜单。
  final AppMenuDisplay? appMenu;
  if (Platform.isMacOS) {
    appMenu = MacosAppMenuService();
  } else {
    appMenu = null;
  }

  final AndroidDisplay? androidDisplay;
  if (Platform.isAndroid) {
    androidDisplay = AndroidDisplayService(repository: repository);
  } else {
    androidDisplay = null;
  }

  final ObsOverlayDisplay? obsOverlay;
  if (Platform.isMacOS || Platform.isWindows) {
    obsOverlay = ObsOverlayService(repository: repository);
  } else {
    obsOverlay = null;
  }

  final viewModel = HomeViewModel(
    repository: repository,
    settings: settings,
    desktopOverlay: desktopOverlay,
    menubar: menubar,
    appMenu: appMenu,
    androidDisplay: androidDisplay,
    obsOverlay: obsOverlay,
  );
  unawaited(viewModel.init());

  runApp(
    MultiProvider(
      providers: [
        Provider<HeartRateRepository>.value(value: repository),
        ChangeNotifierProvider<HomeViewModel>.value(value: viewModel),
      ],
      child: const PulseSightApp(),
    ),
  );
}

/// 主窗口应用。
class PulseSightApp extends StatelessWidget {
  /// 创建应用根组件。
  const PulseSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (_, viewModel, _) => MaterialApp(
        title: 'PulseSight',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // 主题模式由 HomeViewModel 持久化与切换。
        themeMode: viewModel.themeMode,
        home: HomeView(viewModel: viewModel),
      ),
    );
  }
}

/// 桌面悬浮窗副窗口应用,运行于独立引擎(仅 macOS 使用)。
class _DesktopOverlayApp extends StatelessWidget {
  const _DesktopOverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulseSight Overlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DesktopOverlayPage(),
    );
  }
}

/// Windows 悬浮窗**子进程**应用:连接主进程后渲染悬浮窗。
class _OverlayProcessApp extends StatefulWidget {
  const _OverlayProcessApp({required this.link, required this.port});

  final OverlayClientLink link;
  final int port;

  @override
  State<_OverlayProcessApp> createState() => _OverlayProcessAppState();
}

class _OverlayProcessAppState extends State<_OverlayProcessApp> {
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await widget.link.connect(widget.port);
      if (mounted) setState(() => _connected = true);
    } on Object {
      // 主进程已退出或端口失效:保持空白透明界面,由主进程负责回收。
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      // 连接完成前不渲染内容,避免出现空白窗口闪烁。
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.transparent),
      );
    }
    return MaterialApp(
      title: 'PulseSight Overlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: OverlayProcessPage(link: widget.link),
    );
  }
}

/// Android 悬浮窗独立入口。
///
/// flutter_overlay_window 会在独立 isolate 中调用 [overlayMain];
/// 必须带 `@pragma('vm:entry-point')` 防止被裁剪,且必须位于
/// main.dart(入口解析只在根库中进行)。
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AndroidOverlayApp());
}

/// Android 悬浮窗应用。
class _AndroidOverlayApp extends StatelessWidget {
  const _AndroidOverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PulseSight Overlay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AndroidOverlayPage(),
    );
  }
}
