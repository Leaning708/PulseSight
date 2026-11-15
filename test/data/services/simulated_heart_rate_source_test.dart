import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/simulated_heart_rate_source.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';

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

    test('bpm 采样始终在合理区间内', () async {
      final source = SimulatedHeartRateSource(
        connectDelay: connectDelay,
        sampleInterval: sampleInterval,
        random: Random(7),
      );
      final readings = <int>[];
      source.bpmStream.listen(readings.add);

      await source.connect();
      await Future<void>.delayed(settle);

      expect(readings, isNotEmpty);
      for (final bpm in readings) {
        expect(
          bpm,
          inInclusiveRange(SimulatedHeartRateSource.minBpm, SimulatedHeartRateSource.maxBpm),
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
