import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/ui/core/widgets/heartbeat_pulse.dart';

void main() {
  group('beatDuration', () {
    test('按 bpm 计算周期', () {
      expect(HeartbeatPulse.beatDuration(60), const Duration(seconds: 1));
      expect(
        HeartbeatPulse.beatDuration(120),
        const Duration(milliseconds: 500),
      );
      expect(
        HeartbeatPulse.beatDuration(75),
        const Duration(milliseconds: 800),
      );
    });

    test('无效 bpm 返回默认值', () {
      expect(
        HeartbeatPulse.beatDuration(null),
        const Duration(milliseconds: 800),
      );
      expect(HeartbeatPulse.beatDuration(0), const Duration(milliseconds: 800));
      expect(
        HeartbeatPulse.beatDuration(-5),
        const Duration(milliseconds: 800),
      );
    });
  });

  testWidgets('连接时脉冲随时间推进(60bpm 峰值约 1.22)', (tester) async {
    double? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: HeartbeatPulse(
          bpm: 60,
          builder: (context, pulse, phase) {
            captured = pulse.value;
            return const SizedBox();
          },
        ),
      ),
    );
    // t=0:序列起点,scale = 1.0。
    expect(captured, closeTo(1.0, 0.01));

    // 60bpm → 1000ms 周期,180ms 处为扩张峰值。
    await tester.pump(const Duration(milliseconds: 180));
    expect(captured, closeTo(1.22, 0.02), reason: '峰值帧 scale 应约 1.22');

    // 静置段(600ms 后)回到 1.0。
    await tester.pump(const Duration(milliseconds: 500));
    expect(captured, closeTo(1.0, 0.01));
  });

  testWidgets('断连后脉冲复位到 1.0 并静止', (tester) async {
    double? captured;
    Widget buildHeartbeat(int? bpm) => MaterialApp(
      home: HeartbeatPulse(
        bpm: bpm,
        builder: (context, pulse, phase) {
          captured = pulse.value;
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(buildHeartbeat(60));
    await tester.pump(const Duration(milliseconds: 180));
    expect(captured, isNot(closeTo(1.0, 0.01)), reason: '连接中应处于脉冲中');

    await tester.pumpWidget(buildHeartbeat(null));
    expect(captured, closeTo(1.0, 0.01), reason: '断连后应复位到 1.0');

    // 再推进时间:断连后应静止。
    await tester.pump(const Duration(milliseconds: 300));
    expect(captured, closeTo(1.0, 0.01), reason: '断连后不应继续脉冲');
  });

  testWidgets('未连接时直接静止在 1.0', (tester) async {
    double? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: HeartbeatPulse(
          bpm: null,
          builder: (context, pulse, phase) {
            captured = pulse.value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(captured, closeTo(1.0, 1.0));
  });

  testWidgets('bpm 变化后心跳周期跟随新频率(60→180)', (tester) async {
    double? phase;
    Widget buildPulse(int bpm) => MaterialApp(
      home: HeartbeatPulse(
        bpm: bpm,
        builder: (context, pulse, p) {
          phase = p;
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(buildPulse(60));
    // 60bpm → 1000ms 周期:推进半拍,相位约 0.5。
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase, closeTo(0.5, 0.05));

    // 切到 180bpm(周期 333ms):从相位 0.5 衔接再推进 250ms,
    // 按新周期应为 (0.5 * 333 + 250) mod 333 ≈ 83.5ms → 相位约 0.25。
    // 修复前 repeat() 沿用旧周期 1000ms,相位会停在约 0.75。
    await tester.pumpWidget(buildPulse(180));
    await tester.pump(const Duration(milliseconds: 250));
    expect(phase, closeTo(0.25, 0.05), reason: 'bpm 变化后心跳周期应跟随新频率');
  });
}
