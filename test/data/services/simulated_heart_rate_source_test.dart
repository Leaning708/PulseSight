import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/simulated_heart_rate_source.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/heart_rate_scenario.dart';

void main() {
  group('SimulatedHeartRateSource', () {
    // 加速时序,避免真实等待。
    const connectDelay = Duration(milliseconds: 10);
    const sampleInterval = Duration(milliseconds: 10);
    const settle = Duration(milliseconds: 150);

    test('connect 后状态依次经过 connecting → connected', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(42),
      );
      final statuses = <HeartRateConnection>[];
      source.connectionStream.listen(statuses.add);

      await source.connect();
      await Future<void>.delayed(settle);

      expect(statuses.first, HeartRateConnection.connecting);
      expect(statuses, contains(HeartRateConnection.connected));
      expect(source.status, HeartRateConnection.connected);
      expect(source.currentBpm, isNotNull);
      source.dispose();
    });

    test('默认场景为 medium', () {
      final source = SimulatedHeartRateSource(random: Random(2));
      expect(source.scenario, HeartRateScenario.medium);
      source.dispose();
    });

    test('连接后首个采样接近场景基准值', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        scenario: HeartRateScenario.high,
        random: Random(7),
      );
      final readings = <int>[];
      source.bpmStream.listen(readings.add);

      await source.connect();
      await Future<void>.delayed(sampleInterval * 2);

      final base = HeartRateScenario.high.baseBpm;
      expect(readings.first, inInclusiveRange(base - 2, base + 2));
      source.dispose();
    });

    test('bpm 采样始终在场景区间内', () async {
      for (final scenario in HeartRateScenario.values) {
        final source = SimulatedHeartRateSource(
          connectDelay: connectDelay,
          sampleInterval: sampleInterval,
          scenario: scenario,
          random: Random(7),
        );
        final readings = <int>[];
        source.bpmStream.listen(readings.add);

        await source.connect();
        await Future<void>.delayed(settle);

        expect(readings, isNotEmpty, reason: '${scenario.name} 应有采样');
        for (final bpm in readings) {
          expect(
            bpm,
            inInclusiveRange(scenario.minBpm, scenario.maxBpm),
            reason: '${scenario.name} bpm=$bpm 超界',
          );
        }
        source.dispose();
      }
    });

    test('连接中切换场景:bpm 平滑过渡而非瞬间跳变', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(11),
      );
      final readings = <int>[];
      source.bpmStream.listen(readings.add);

      await source.connect();
      await Future<void>.delayed(settle);

      // medium → low:切换后首个采样应仍接近原值(未瞬间钳制到新区间)。
      readings.clear();
      source.setScenario(HeartRateScenario.low);
      await Future<void>.delayed(sampleInterval * 2);
      expect(
        readings.first,
        greaterThan(HeartRateScenario.low.maxBpm),
        reason: '场景切换不应瞬间跳变到新区间',
      );

      // 过渡完成后收敛进新区间。
      await Future<void>.delayed(settle);
      readings.clear();
      await Future<void>.delayed(settle);
      for (final bpm in readings) {
        expect(
          bpm,
          inInclusiveRange(
            HeartRateScenario.low.minBpm,
            HeartRateScenario.low.maxBpm,
          ),
          reason: '过渡后 bpm=$bpm 应收敛到 low 区间',
        );
      }
      source.dispose();
    });

    test('连接中向高档切换:同样平滑过渡', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        scenario: HeartRateScenario.low,
        random: Random(5),
      );
      final readings = <int>[];
      source.bpmStream.listen(readings.add);

      await source.connect();
      await Future<void>.delayed(settle);

      readings.clear();
      source.setScenario(HeartRateScenario.high);
      await Future<void>.delayed(sampleInterval * 2);
      expect(
        readings.first,
        lessThan(HeartRateScenario.high.minBpm),
        reason: '场景切换不应瞬间跳变到新区间',
      );

      await Future<void>.delayed(settle * 2);
      readings.clear();
      await Future<void>.delayed(settle);
      for (final bpm in readings) {
        expect(
          bpm,
          inInclusiveRange(
            HeartRateScenario.high.minBpm,
            HeartRateScenario.high.maxBpm,
          ),
          reason: '过渡后 bpm=$bpm 应收敛到 high 区间',
        );
      }
      source.dispose();
    });

    test('断开状态切换场景,重连后按新场景生成', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(3),
      );
      final readings = <int>[];
      source.bpmStream.listen(readings.add);

      source.setScenario(HeartRateScenario.low);
      await source.connect();
      await Future<void>.delayed(settle);

      expect(readings, isNotEmpty);
      expect(
        readings.first,
        inInclusiveRange(
          HeartRateScenario.low.baseBpm - 2,
          HeartRateScenario.low.baseBpm + 2,
        ),
        reason: '重连应以场景基准值起步',
      );
      for (final bpm in readings) {
        expect(
          bpm,
          inInclusiveRange(
            HeartRateScenario.low.minBpm,
            HeartRateScenario.low.maxBpm,
          ),
          reason: 'bpm=$bpm 超界',
        );
      }
      source.dispose();
    });

    test('disconnect 后回到未连接状态并清空心率', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(1),
      );
      await source.connect();
      await Future<void>.delayed(settle);

      await source.disconnect();
      await Future<void>.delayed(settle);

      expect(source.status, HeartRateConnection.disconnected);
      expect(source.currentBpm, isNull);
      source.dispose();
    });

    test('已连接时重复 connect 不会再次触发 connecting', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(3),
      );
      final statuses = <HeartRateConnection>[];
      source.connectionStream.listen(statuses.add);

      await source.connect();
      await Future<void>.delayed(settle);
      statuses.clear();

      await source.connect();
      await Future<void>.delayed(settle);

      expect(statuses, isEmpty);
      expect(source.status, HeartRateConnection.connected);
      source.dispose();
    });

    test('初始状态为未连接', () {
      final source = SimulatedHeartRateSource(random: Random(2));
      expect(source.status, HeartRateConnection.disconnected);
      expect(source.currentBpm, isNull);
      source.dispose();
    });
  });
}
