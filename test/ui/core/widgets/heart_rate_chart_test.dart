import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/ui/core/widgets/heart_rate_chart.dart';

void main() {
  Widget buildChart(List<int> values) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 180,
        height: 84,
        child: HeartRateChart(values: values, lineColor: Colors.white),
      ),
    ),
  );

  testWidgets('空数据渲染占位平线无异常', (tester) async {
    await tester.pumpWidget(buildChart([]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('单个采样点渲染占位平线无异常', (tester) async {
    await tester.pumpWidget(buildChart([72]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('多个采样点正常渲染折线', (tester) async {
    await tester.pumpWidget(buildChart([60, 72, 88, 75, 90, 68]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('大量采样点(40 个)渲染无异常', (tester) async {
    await tester.pumpWidget(buildChart(List.generate(40, (i) => 60 + i % 30)));
    expect(tester.takeException(), isNull);
  });
}
