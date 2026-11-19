import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';
import 'package:pulse_sight/ui/features/home/views/sections/overlay_style_section.dart';

import '../home_view_model_test.dart'
    show FakeScenarioHeartRateSource, FakeSettingsRepository;

void main() {
  /// 在给定可用宽度下渲染样式控件;返回 viewModel 便于断言与改色。
  Future<HomeViewModel> pumpControls(
    WidgetTester tester, {
    required double width,
  }) async {
    final repository = HeartRateRepository(
      source: FakeScenarioHeartRateSource(),
    );
    final viewModel = HomeViewModel(
      repository: repository,
      settings: FakeSettingsRepository(),
    );
    await viewModel.init();
    addTearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: OverlayStyleControls(viewModel: viewModel),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  /// 校验某组色板行的所有圆点处于同一行(相邻圆点的 y 中心一致)。
  void expectSingleRow(WidgetTester tester, String id, {int expected = 9}) {
    final row = find.byKey(Key('swatch_row_$id'));
    expect(row, findsOneWidget, reason: '缺少 $id 的色板行');
    final swatches = find.descendant(
      of: row,
      matching: find.byType(InkResponse),
    );
    expect(swatches, findsNWidgets(expected), reason: '$id 应为一排色板');
    final firstDy = tester.getCenter(swatches.first).dy;
    for (var i = 1; i < expected; i++) {
      expect(
        tester.getCenter(swatches.at(i)).dy,
        moreOrLessEquals(firstDy, epsilon: 0.5),
        reason: '$id 的第 $i 个圆点折到了下一行',
      );
    }
  }

  group('OverlayStyleControls 色板始终单行', () {
    testWidgets('窄屏(320)下 8 备选 + 1 自定义仍为一行且不溢出', (tester) async {
      await pumpControls(tester, width: 320);

      expect(tester.takeException(), isNull);
      expectSingleRow(tester, 'heart');
      expectSingleRow(tester, 'text');
      expectSingleRow(tester, 'ecg');
      expectSingleRow(tester, 'background');
      expectSingleRow(tester, 'chart');
    });

    testWidgets('手机常见宽度(400)下仍为一行', (tester) async {
      await pumpControls(tester, width: 400);

      expect(tester.takeException(), isNull);
      expectSingleRow(tester, 'heart');
    });

    testWidgets('桌面宽窗口(720)下仍为一行且圆点不无限放大', (tester) async {
      await pumpControls(tester, width: 720);

      expect(tester.takeException(), isNull);
      expectSingleRow(tester, 'heart');

      // 槽位变宽时圆点直径有上限,不会拉成巨型色块。
      final swatch = find
          .descendant(
            of: find.byKey(const Key('swatch_row_heart')),
            matching: find.byType(AnimatedContainer),
          )
          .first;
      expect(tester.getSize(swatch).width, lessThanOrEqualTo(30));
    });
  });

  group('辉光开关', () {
    testWidgets('关闭后半径/透明度禁用,重新打开恢复可调', (tester) async {
      final viewModel = await pumpControls(tester, width: 400);

      Slider sliderOf(String id) => tester.widget<Slider>(
        find.descendant(
          of: find.byKey(Key('style_slider_$id')),
          matching: find.byType(Slider),
        ),
      );

      expect(viewModel.overlayStyle.glowEnabled, isTrue);
      expect(sliderOf('glow_radius').onChanged, isNotNull);

      viewModel.setOverlayGlowEnabled(false);
      await tester.pumpAndSettle();

      expect(viewModel.overlayStyle.glowEnabled, isFalse);
      expect(sliderOf('glow_radius').onChanged, isNull, reason: '辉光关闭时半径不可调');
      expect(sliderOf('glow_opacity').onChanged, isNull);

      viewModel.setOverlayGlowEnabled(true);
      await tester.pumpAndSettle();
      expect(sliderOf('glow_radius').onChanged, isNotNull);
    });

    testWidgets('开关状态写入持久化设置', (tester) async {
      final viewModel = await pumpControls(tester, width: 400);
      viewModel.setOverlayGlowEnabled(false);

      // persistOverlayStyle 是异步落盘,等一轮事件循环。
      await tester.pumpAndSettle();
      expect(viewModel.overlayStyle.glowEnabled, isFalse);
    });
  });

  group('自定义颜色', () {
    /// 取「图形 · 颜色」行末尾的自定义入口。
    Finder customSwatch() => find
        .descendant(
          of: find.byKey(const Key('swatch_row_heart')),
          matching: find.byType(InkResponse),
        )
        .last;

    /// 读取色板圆点当前的外圈颜色。
    Color ringColorOf(WidgetTester tester, Finder swatch) {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(of: swatch, matching: find.byType(AnimatedContainer)),
      );
      final decoration = box.decoration! as BoxDecoration;
      return decoration.border!.top.color;
    }

    testWidgets('自定义色被选中时,自定义入口外圈用该颜色而非主题主色', (tester) async {
      final viewModel = await pumpControls(tester, width: 400);
      const custom = Color(0xFF00897B);

      viewModel.setOverlayHeartColor(custom);
      await tester.pumpAndSettle();

      expect(ringColorOf(tester, customSwatch()), custom);
      // 主题主色不应再出现在这个外圈上。
      final theme = AppTheme.light.colorScheme.primary;
      expect(ringColorOf(tester, customSwatch()), isNot(theme));
    });

    testWidgets('选中预设色时,自定义入口回落为普通未选中描边', (tester) async {
      final viewModel = await pumpControls(tester, width: 400);
      viewModel.setOverlayHeartColor(const Color(0xFFFFC107));
      await tester.pumpAndSettle();

      final ring = ringColorOf(tester, customSwatch());
      final scheme = AppTheme.light.colorScheme;
      // 未选中态统一用 onSurface 低透明度描边。
      expect(ring.a, lessThan(0.3));
      expect(ring, isNot(scheme.primary));
    });

    testWidgets('hex 输入框与调色盘双向同步,确定后写入样式', (tester) async {
      final viewModel = await pumpControls(tester, width: 400);

      await tester.tap(customSwatch());
      await tester.pumpAndSettle();

      final hexField = find.byKey(const Key('color_hex_input'));
      expect(hexField, findsOneWidget);

      // 直接键入 hex:调色盘随输入更新,确定后样式使用该颜色。
      await tester.enterText(hexField, '#1E88E5');
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(viewModel.overlayStyle.heartColor, const Color(0xFF1E88E5));

      // 再次打开时,输入框应回显当前自定义色(调色盘 → 输入框方向)。
      await tester.tap(customSwatch());
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(hexField).controller!.text.toUpperCase(),
        '#1E88E5',
      );
    });
  });
}
