import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/core/widgets/setting_row.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';
import 'package:pulse_sight/ui/features/home/views/home_view.dart';

import '../home_view_model_test.dart'
    show
        FakeDesktopOverlay,
        FakeMenubarDisplay,
        FakeObsOverlayDisplay,
        FakeScenarioHeartRateSource,
        FakeSettingsRepository;

/// 按给定窗口尺寸渲染 [HomeView],返回 [viewModel] 与设置 Fake。
///
/// 脚手架与 PulseSightApp 一致,通过 [ListenableBuilder] 跟随
/// viewModel 的主题模式;心跳动画持续运行,只能逐帧 pump,不能 settle。
Future<(HomeViewModel, FakeSettingsRepository)> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final settings = FakeSettingsRepository();
  final repository = HeartRateRepository(source: FakeScenarioHeartRateSource());
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
      expect(find.text('模拟心率场景'), findsOneWidget);
    });

    testWidgets('宽窗口渲染桌面设置式布局(导航栏 + 监视器默认页)', (tester) async {
      await _pump(tester, width: 1200, height: 800);

      expect(find.byKey(const Key('home_desktop_layout')), findsOneWidget);
      expect(find.byKey(const Key('home_narrow_layout')), findsNothing);
      // 导航栏与四个条目齐全。
      expect(find.byKey(const Key('desktop_nav_rail')), findsOneWidget);
      for (final name in ['monitor', 'scenario', 'display', 'style']) {
        expect(find.byKey(Key('desktop_nav_$name')), findsOneWidget);
      }
      // 默认停留在监视器页:连接按钮可见,其余详情面板离屏不渲染。
      expect(find.byKey(const Key('desktop_pane_monitor')), findsOneWidget);
      expect(find.text('连接手环(模拟)'), findsOneWidget);
      expect(find.byKey(const Key('desktop_pane_display')), findsNothing);
      expect(find.byKey(const Key('desktop_pane_style')), findsNothing);
      // 测试环境为 macOS:窗口按钮由系统红绿灯承担,不渲染 Windows 自绘按钮。
      expect(find.byType(WindowCaptionButton), findsNothing);
    });

    testWidgets('点击导航栏切换详情面板', (tester) async {
      await _pump(tester, width: 1200, height: 800);

      await tester.tap(find.byKey(const Key('desktop_nav_display')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_display')), findsOneWidget);
      expect(find.byKey(const Key('desktop_pane_monitor')), findsNothing);
      expect(find.byType(SettingRow), findsWidgets);

      await tester.tap(find.byKey(const Key('desktop_nav_scenario')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_scenario')), findsOneWidget);
      expect(find.text('低'), findsOneWidget);
      expect(find.text('中'), findsOneWidget);
      expect(find.text('高'), findsOneWidget);

      await tester.tap(find.byKey(const Key('desktop_nav_style')));
      await tester.pump();
      expect(find.byKey(const Key('desktop_pane_style')), findsOneWidget);
      // 样式控件按语义分组,组标题与实时预览齐全。
      expect(find.text('尺寸与布局'), findsOneWidget);
      expect(find.text('颜色'), findsOneWidget);
      expect(find.text('图表'), findsOneWidget);
      expect(find.text('动效与文字'), findsOneWidget);
      expect(find.text('实时预览 · 与悬浮窗观感一致'), findsOneWidget);
      // 切走后监视器页的连接按钮离屏。
      expect(find.text('连接手环(模拟)'), findsNothing);
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
}
