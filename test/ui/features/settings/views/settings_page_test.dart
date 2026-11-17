import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:pulse_sight/data/services/platform/font_list_service.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';
import 'package:pulse_sight/ui/features/settings/views/sections/global_font_section.dart';
import 'package:pulse_sight/ui/features/settings/views/settings_page.dart';

import '../../home/home_view_model_test.dart'
    show FakeScenarioHeartRateSource, FakeSettingsRepository;

/// 渲染设置页,返回 viewModel / 设置 Fake。
Future<(HomeViewModel, FakeSettingsRepository)> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final settings = FakeSettingsRepository();
  final repository = HeartRateRepository(source: FakeScenarioHeartRateSource());
  final fontList = FontListService(
    loader: () async => ['Microsoft YaHei', 'Arial'],
  );
  final viewModel = HomeViewModel(
    repository: repository,
    settings: settings,
    fontListService: fontList,
  );
  await viewModel.init();
  await fontList.ready;
  addTearDown(() {
    viewModel.dispose();
    repository.dispose();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SettingsPage(viewModel: viewModel),
    ),
  );
  await tester.pump();
  return (viewModel, settings);
}

void main() {
  group('设置页 · 全局字体', () {
    testWidgets('展示系统字体列表,默认选中系统默认', (tester) async {
      final (viewModel, _) = await _pump(tester);

      expect(find.byKey(const Key('settings_page')), findsOneWidget);
      expect(find.text('全局字体'), findsOneWidget);
      expect(find.byKey(GlobalFontSection.dropdownKey), findsOneWidget);
      expect(find.text('系统默认'), findsOneWidget);
      expect(viewModel.fontFamilies, ['Arial', 'Microsoft YaHei']);
      expect(viewModel.globalFontFamily, isNull);
    });

    testWidgets('选择字体后更新 viewModel 并持久化', (tester) async {
      final (viewModel, settings) = await _pump(tester);

      await tester.tap(find.byKey(GlobalFontSection.dropdownKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Microsoft YaHei').last);
      await tester.pumpAndSettle();

      expect(viewModel.globalFontFamily, 'Microsoft YaHei');
      expect(settings.store[SettingsKeys.globalFontFamily], 'Microsoft YaHei');
      expect(find.text('当前:Microsoft YaHei'), findsOneWidget);

      // 重新选回系统默认会移除持久化值。
      await tester.tap(find.byKey(GlobalFontSection.dropdownKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('系统默认').last);
      await tester.pumpAndSettle();

      expect(viewModel.globalFontFamily, isNull);
      expect(settings.store[SettingsKeys.globalFontFamily], isNull);
    });
  });
}
