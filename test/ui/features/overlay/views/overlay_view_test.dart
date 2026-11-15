import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/domain/models/heart_rate_history.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';
import 'package:pulse_sight/ui/core/widgets/bpm_display.dart';
import 'package:pulse_sight/ui/core/widgets/heart_rate_chart.dart';
import 'package:pulse_sight/ui/core/widgets/heartbeat_heart.dart';
import 'package:pulse_sight/ui/features/overlay/views/overlay_view.dart';

void main() {
  /// 填充若干采样点,使折线图正常绘制。
  HeartRateHistory historyWithSamples() {
    final history = HeartRateHistory();
    for (var i = 0; i < 10; i++) {
      history.add(70 + i);
    }
    return history;
  }

  Widget buildOverlay(OverlayStyle style) {
    return OverlayView(
      bpm: 72,
      connected: true,
      history: historyWithSamples(),
      style: style,
    );
  }

  double contentBottom(WidgetTester tester) =>
      tester.getRect(find.byType(BpmDisplay)).bottom;

  double chartTop(WidgetTester tester) =>
      tester.getRect(find.byType(HeartRateChart)).top;

  testWidgets('折线图开启且 spacing 为 0 时内容紧贴折线图', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildOverlay(
            const OverlayStyle(
              showChart: true,
              chartSpacing: 0,
              backgroundWidth: 240,
              backgroundHeight: 280,
            ),
          ),
        ),
      ),
    );

    expect(
      chartTop(tester) - contentBottom(tester),
      lessThan(1.5),
      reason: 'spacing=0 时内容与折线图之间不应有额外空隙',
    );
  });

  testWidgets('折线图 spacing 滑块值即内容与折线图的实际间距', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildOverlay(
            const OverlayStyle(
              showChart: true,
              chartSpacing: 6,
              backgroundWidth: 240,
              backgroundHeight: 280,
            ),
          ),
        ),
      ),
    );

    final gap = chartTop(tester) - contentBottom(tester);
    expect(gap, closeTo(6, 1.5), reason: '间距应约等于 chartSpacing=6');
  });

  testWidgets('折线图关闭时内容保持垂直居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildOverlay(
            const OverlayStyle(backgroundWidth: 240, backgroundHeight: 280),
          ),
        ),
      ),
    );

    expect(find.byType(HeartRateChart), findsNothing);

    // 内容列为 [心形, 间距, bpm],其几何中心应与背景板中心重合。
    final heartRect = tester.getRect(find.byType(HeartbeatHeart));
    final bpmRect = tester.getRect(find.byType(BpmDisplay));
    final contentCenter = (heartRect.top + bpmRect.bottom) / 2;
    final panelCenter = tester.getRect(find.byType(OverlayView)).center.dy;
    expect(contentCenter, closeTo(panelCenter, 2.0), reason: '无折线图时内容应垂直居中');
  });
}
