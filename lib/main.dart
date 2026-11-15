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
import 'data/services/simulated_heart_rate_source.dart';
import 'domain/models/heart_rate_scenario.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/overlay/views/android_overlay_page.dart';
import 'ui/features/overlay/views/desktop_overlay_page.dart';

/// 应用入口。
///
/// 桌面端(macOS / Windows)下,desktop_multi_window 创建的悬浮窗副窗口
/// 会以同一入口启动新引擎,通过 [WindowController.arguments] 区分:
/// 主窗口参数为空,悬浮窗参数为 [DesktopOverlayService.overlayWindowArgument]。
///
/// 注意:Android 悬浮窗入口 [overlayMain] 也必须定义在 main.dart——
/// flutter_overlay_window 的 DartEntrypoint 只在根库中解析入口函数。
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isWindows) {
    final controller = await WindowController.fromCurrentEngine();
    if (controller.arguments == DesktopOverlayService.overlayWindowArgument) {
      runApp(const _DesktopOverlayApp());
      return;
    }
  }
  await _runMainApp();
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
  if (Platform.isMacOS || Platform.isWindows) {
    desktopOverlay = DesktopOverlayService(repository: repository);
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

/// 桌面悬浮窗副窗口应用,运行于独立引擎。
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
