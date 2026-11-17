import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:pulse_sight/data/services/heart_rate_source.dart';
import 'package:pulse_sight/data/services/simulated_heart_rate_source.dart';
import 'package:pulse_sight/data/services/switchable_heart_rate_source.dart';
import 'package:pulse_sight/domain/models/heart_rate_device.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/core/widgets/setting_row.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';

import '../../../../data/services/real_heart_rate_source_fake.dart';

import 'package:pulse_sight/ui/features/home/views/home_view.dart';

import '../home_view_model_test.dart'
    show
        FakeDesktopOverlay,
        FakeMenubarDisplay,
        FakeObsOverlayDisplay,
        FakeScenarioHeartRateSource,
        FakeScannerHeartRateSource,
        FakeSettingsRepository;

/// 测试环境无 window_manager 原生插件,mock 基础查询通道。
void _mockWindowManagerChannel() {
  const channel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'isMaximized':
          case 'isFullScreen':
          case 'isMinimized':
          case 'isVisible':
          case 'isAlwaysOnTop':
          case 'isPreventClose':
          case 'isSkipTaskbar':
          case 'isResizable':
          case 'isFocused':
            return false;
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

/// 按给定窗口尺寸渲染 [HomeView],返回 [viewModel] 与设置 Fake。
///
/// 脚手架与 PulseSightApp 一致,通过 [ListenableBuilder] 跟随
/// viewModel 的主题模式;心跳动画持续运行,只能逐帧 pump,不能 settle。
Future<(HomeViewModel, FakeSettingsRepository)> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  HeartRateSource? source,
  FakeSettingsRepository? initialSettings,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _mockWindowManagerChannel();

  final settings = initialSettings ?? FakeSettingsRepository();
  final repository = HeartRateRepository(
    source: source ?? FakeScenarioHeartRateSource(),
  );
  final viewModel = HomeViewModel(
    repository: repository,
    settings: settings,
    desktopOverlay: FakeDesktopOverlay(),
    menubar: FakeMenubarDisplay(),
    obsOverlay: FakeObsOverlayDisplay(),
  );
  await viewModel.init();
  addTearDown(() {
    viewModel.dispose();
    repository.dispose();
  });

  await tester.pumpWidget(
    ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: viewModel.themeMode,
        home: HomeView(viewModel: viewModel),
      ),
    ),
  );
  await tester.pump();
  return (viewModel, settings);
}

void main() {
  group('HomeView 布局自适应', () {
    testWidgets('窄窗口渲染手机布局(单列,含 AppBar)', (tester) async {
      await _pump(tester, width: 400, height: 900);

      expect(find.byKey(const Key('home_narrow_layout')), findsOneWidget);
      expect(find.byKey(const Key('home_desktop_layout')), findsNothing);
      expect(find.text('PulseSight'), findsOneWidget);
      expect(find.text('开始模拟'), findsOneWidget);
      expect(find.text('低'), findsOneWidget);
    });

    testWidgets('窄布局从标题栏进入设置页', (tester) async {
      await _pump(tester, width: 400, height: 900);

      await tester.tap(find.byKey(const Key('open_settings_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('settings_page')), findsOneWidget);
      expect(find.text('全局字体'), findsOneWidget);
    });

    testWidgets('宽窗口渲染桌面设置式布局(导航栏 + 监视器默认页)', (tester) async {
      await _pump(tester, width: 1200, height: 800);

      expect(find.byKey(const Key('home_desktop_layout')), findsOneWidget);
      expect(find.byKey(const Key('home_narrow_layout')), findsNothing);
      // 导航栏与四个条目齐全,模拟场景不再单独成页。
      expect(find.byKey(const Key('desktop_nav_rail')), findsOneWidget);
      for (final name in ['monitor', 'display', 'style', 'settings']) {
        expect(find.byKey(Key('desktop_nav_$name')), findsOneWidget);
      }
      expect(find.byKey(const Key('desktop_nav_scenario')), findsNothing);
      // 默认停留在监视器页:连接按钮可见,其余详情面板离屏不渲染。
      expect(find.byKey(const Key('desktop_pane_monitor')), findsOneWidget);
      expect(find.text('开始模拟'), findsOneWidget);
      expect(find.byKey(const Key('desktop_pane_display')), findsNothing);
      expect(find.byKey(const Key('desktop_pane_style')), findsNothing);
      expect(find.byKey(const Key('desktop_pane_settings')), findsNothing);
      // 窗口控制按钮:Windows 上标题栏由 Flutter 自绘承担,三个按钮
      // 必须贴主窗口右上角;macOS 由系统红绿灯承担,不渲染。
      if (Platform.isWindows) {
        expect(find.byType(WindowCaptionButton), findsNWidgets(3));
        final windowWidth = tester.view.physicalSize.width;
        final rects = [
          for (var i = 0; i < 3; i++)
            tester.getRect(find.byType(WindowCaptionButton).at(i)),
        ];
        // 最右侧按钮贴最右缘,全部贴顶缘,且整组远离标题区域。
        expect(rects[2].right, windowWidth, reason: '按钮应贴最右缘');
        for (final rect in rects) {
          expect(rect.top, 0, reason: '按钮应贴顶缘');
          expect(
            rect.left,
            greaterThan(windowWidth - 200),
            reason: '按钮应位于右上角而非标题下',
          );
        }
      } else {
        expect(find.byType(WindowCaptionButton), findsNothing);
      }
    });

    testWidgets('点击导航栏切换详情面板', (tester) async {
      await _pump(tester, width: 1200, height: 800);

      await tester.tap(find.byKey(const Key('desktop_nav_display')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_display')), findsOneWidget);
      expect(find.byKey(const Key('desktop_pane_monitor')), findsNothing);
      expect(find.byType(SettingRow), findsWidgets);

      await tester.tap(find.byKey(const Key('desktop_nav_style')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_style')), findsOneWidget);
      // 样式控件按语义分组,组标题与实时预览齐全。
      expect(find.text('尺寸与布局'), findsOneWidget);
      expect(find.text('颜色'), findsOneWidget);
      expect(find.text('图表'), findsOneWidget);
      expect(find.text('动效与文字'), findsOneWidget);
      expect(find.text('实时预览 · 与悬浮窗观感一致'), findsOneWidget);
      // 颜色分组用「心形颜色」;字体默认项跟随全局字体而非系统默认。
      expect(find.text('心形颜色'), findsOneWidget);
      expect(find.text('跟随全局(系统默认)'), findsOneWidget);
      // 切走后监视器页的连接按钮离屏。
      expect(find.text('开始模拟'), findsNothing);

      await tester.tap(find.byKey(const Key('desktop_nav_settings')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_settings')), findsOneWidget);
      expect(find.text('全局字体'), findsOneWidget);
      expect(find.byKey(const Key('desktop_pane_style')), findsNothing);
    });

    testWidgets('接近断点的桌面宽度下样式页退化为堆叠布局且无溢出', (tester) async {
      await _pump(tester, width: 760, height: 700);

      expect(find.byKey(const Key('home_desktop_layout')), findsOneWidget);
      await tester.tap(find.byKey(const Key('desktop_nav_style')));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('主题按钮循环切换并持久化', (tester) async {
      final (viewModel, settings) = await _pump(
        tester,
        width: 1200,
        height: 800,
      );
      expect(viewModel.themeMode, ThemeMode.system);

      await tester.tap(find.byKey(const Key('theme_mode_button')));
      await tester.pump();
      expect(viewModel.themeMode, ThemeMode.light);

      await tester.tap(find.byKey(const Key('theme_mode_button')));
      await tester.pump();
      expect(viewModel.themeMode, ThemeMode.dark);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      await tester.pump(const Duration(milliseconds: 100));
      expect(settings.store[SettingsKeys.themeMode], 'dark');
    });
  });

  group('设备选择', () {
    testWidgets('连接设备弹窗扫描并列出心率设备', (tester) async {
      final scanner = FakeScannerHeartRateSource();
      await _pump(tester, width: 400, height: 900, source: scanner);

      await tester.tap(find.text('连接设备'));
      await tester.pump();
      // 扫描在弹窗首帧后启动,再 pump 一帧刷新扫描状态。
      await tester.pump();

      expect(find.byKey(const Key('device_picker_dialog')), findsOneWidget);
      expect(find.text('正在搜索附近的心率设备…'), findsOneWidget);

      scanner.emitDevices(const [
        HeartRateDevice(
          id: 'band-1',
          name: 'Xiaomi Smart Band 10',
          rssi: -48,
          advertisesHeartRate: true,
        ),
        HeartRateDevice(id: 'buds', name: 'AirPods', rssi: -70),
      ]);
      await tester.pump();

      // 默认只显示广播了心率服务的设备。
      expect(find.text('Xiaomi Smart Band 10'), findsOneWidget);
      expect(find.text('AirPods'), findsNothing);

      await tester.tap(find.text('显示全部蓝牙设备'));
      await tester.pump();
      expect(find.text('AirPods'), findsOneWidget);

      await tester.tap(find.text('Xiaomi Smart Band 10'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('device_picker_dialog')), findsNothing);
      expect(scanner.calls, contains('connectTo:band-1'));
    });

    testWidgets('扫描无结果时仍显示上次连接设备并可重连', (tester) async {
      final scanner = FakeScannerHeartRateSource();
      final settings = FakeSettingsRepository()
        ..store[SettingsKeys.bleLastDeviceId] = 'band-1'
        ..store[SettingsKeys.bleLastDeviceName] = 'Xiaomi Smart Band 10';
      await _pump(
        tester,
        width: 400,
        height: 900,
        source: scanner,
        initialSettings: settings,
      );

      await tester.tap(find.text('连接设备'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Xiaomi Smart Band 10'), findsOneWidget);
      expect(find.textContaining('上次连接'), findsOneWidget);

      await tester.tap(find.text('Xiaomi Smart Band 10'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('device_picker_dialog')), findsNothing);
      expect(scanner.calls, contains('connectTo:band-1'));
    });

    testWidgets('连接成功后显示设备名与断开按钮', (tester) async {
      final scanner = FakeScannerHeartRateSource();
      final (viewModel, _) = await _pump(
        tester,
        width: 400,
        height: 900,
        source: scanner,
      );

      await viewModel.connectToDevice(
        const HeartRateDevice(
          id: 'band-1',
          name: 'Xiaomi Smart Band 10',
          advertisesHeartRate: true,
        ),
      );
      await tester.pump();

      expect(find.text('已连接'), findsOneWidget);
      expect(find.text('设备:Xiaomi Smart Band 10'), findsOneWidget);
      expect(find.text('断开连接'), findsOneWidget);
    });
  });

  group('真实 / 模拟模式 UI', () {
    testWidgets('通过连接弹窗进入模拟模式,停止后回到真实模式', (tester) async {
      final realSource = FakeRealHeartRateSource();
      final simulatedSource = SimulatedHeartRateSource(
        connectDelay: Duration.zero,
        sampleInterval: const Duration(hours: 1),
      );
      final switchable = SwitchableHeartRateSource(
        real: realSource,
        simulated: simulatedSource,
      );
      final (viewModel, _) = await _pump(
        tester,
        width: 400,
        height: 900,
        source: switchable,
      );

      expect(find.byKey(const Key('heart_rate_mode_selector')), findsNothing);
      expect(find.text('连接设备'), findsOneWidget);

      await tester.tap(find.byKey(const Key('connection_primary_button')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('device_picker_dialog')), findsOneWidget);
      expect(
        find.byKey(const Key('device_picker_use_simulation')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('device_picker_use_simulation')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isSimulatedMode, isTrue);
      expect(find.text('停止模拟'), findsOneWidget);
      // 三档场景直接排在连接按钮下方。
      expect(find.text('低'), findsOneWidget);
      expect(find.text('中'), findsOneWidget);
      expect(find.text('高'), findsOneWidget);

      await tester.tap(find.byKey(const Key('connection_primary_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isSimulatedMode, isFalse);
      expect(find.text('连接设备'), findsOneWidget);
      expect(find.text('低'), findsNothing);
      expect(find.text('中'), findsNothing);
      expect(find.text('高'), findsNothing);
      expect(realSource.calls, contains('disconnect'));
    });
  });
}
