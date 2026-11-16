import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/services/platform/desktop_overlay_service.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';
import 'package:pulse_sight/ui/features/home/views/sections/display_toggles_section.dart';

import '../home_view_model_test.dart'
    show
        FakeDesktopOverlay,
        FakeObsOverlayDisplay,
        FakeScenarioHeartRateSource,
        FakeSettingsRepository;

void main() {
  /// 渲染显示端开关区;返回 viewModel 便于断言。
  Future<HomeViewModel> pumpSection(
    WidgetTester tester, {
    DesktopOverlay? desktopOverlay,
  }) async {
    final repository = HeartRateRepository(
      source: FakeScenarioHeartRateSource(),
    );
    final viewModel = HomeViewModel(
      repository: repository,
      settings: FakeSettingsRepository(),
      desktopOverlay: desktopOverlay,
      obsOverlay: FakeObsOverlayDisplay(),
    );
    await viewModel.init();
    addTearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DisplayTogglesSection(viewModel: viewModel),
          ),
        ),
      ),
    );
    await tester.pump();
    return viewModel;
  }

  testWidgets('支持桌面悬浮窗时渲染开关与穿透行(穿透默认禁用)', (tester) async {
    await pumpSection(tester, desktopOverlay: FakeDesktopOverlay());

    expect(find.text('桌面悬浮窗'), findsOneWidget);
    expect(find.text('鼠标穿透'), findsOneWidget);
    // 悬浮窗未开启时穿透开关应由 onChanged == null 呈现禁用态。
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(greaterThanOrEqualTo(2)));
    expect(switches.first.onChanged, isNotNull, reason: '桌面悬浮窗开关应可操作');
    expect(switches[1].onChanged, isNull, reason: '悬浮窗关闭时穿透不可操作');
  });

  testWidgets('不支持桌面悬浮窗的平台不渲染悬浮窗相关行', (tester) async {
    await pumpSection(tester);

    expect(find.text('桌面悬浮窗'), findsNothing);
    expect(find.text('鼠标穿透'), findsNothing);
    // OBS 浏览器源仍然可用。
    expect(find.text('OBS 浏览器源'), findsOneWidget);
  });
}
