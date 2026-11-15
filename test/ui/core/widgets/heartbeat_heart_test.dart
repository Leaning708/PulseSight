import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/ui/core/widgets/heartbeat_heart.dart';

void main() {
  group('HeartbeatHeart', () {
    testWidgets('未连接时渲染静止灰心', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: HeartbeatHeart(size: 80))),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HeartbeatHeart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HeartbeatHeart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('连接后按 bpm 播放跳动动画', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: HeartbeatHeart(size: 80, bpm: 60)),
          ),
        ),
      );
      // 推进数帧,覆盖脉冲序列的多个阶段。
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.descendant(
          of: find.byType(HeartbeatHeart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('bpm 变化时切换动画周期且不抛异常', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: HeartbeatHeart(size: 80, bpm: 60)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: HeartbeatHeart(size: 80, bpm: 120)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // bpm 从有值变为 null 应回退到未连接灰心。
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: HeartbeatHeart(size: 80))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    test('布局映射使心形中心落在画布中心(脉冲缩放不偏移)', () {
      for (final size in [
        const Size(64, 64),
        const Size(100, 100),
        const Size(180, 180),
        const Size(140, 170),
      ]) {
        final layout = HeartbeatHeart.layoutFor(size);
        // 心形中心(24 视窗内 12, 12.175)映射到画布坐标。
        final centerX = layout.dx + 12 * layout.s;
        final centerY = layout.dy + 12.175 * layout.s;
        expect(
          centerX,
          closeTo(size.width / 2, 0.001),
          reason: 'size=$size 水平中心偏移',
        );
        expect(
          centerY,
          closeTo(size.height / 2, 0.001),
          reason: 'size=$size 垂直中心偏移',
        );
      }
    });

    group('ecgDrawInfo', () {
      test('相位 0 返回 null(避免波形起点的圆头白点伪影)', () {
        expect(HeartbeatHeart.ecgDrawInfo(0), isNull);
      });

      test('绘制段:透明度 1.0,进度按比例推进', () {
        final info = HeartbeatHeart.ecgDrawInfo(0.2)!;
        expect(info.alpha, 1.0);
        expect(info.drawProgress, closeTo(0.2 / 0.45, 0.001));
      });

      test('保持段:完整显示', () {
        final info = HeartbeatHeart.ecgDrawInfo(0.5)!;
        expect(info.alpha, 1.0);
        expect(info.drawProgress, 1.0);
      });

      test('淡出段:进度保持完整,透明度线性衰减', () {
        final info = HeartbeatHeart.ecgDrawInfo(0.75)!;
        expect(info.drawProgress, 1.0);
        expect(info.alpha, closeTo(1.0 - (0.75 - 0.60) / (0.90 - 0.60), 0.001));
      });

      test('静置段返回 null', () {
        expect(HeartbeatHeart.ecgDrawInfo(0.95), isNull);
        expect(HeartbeatHeart.ecgDrawInfo(1.0), isNull);
      });
    });
  });
}
