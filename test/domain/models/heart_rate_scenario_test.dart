import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/domain/models/heart_rate_scenario.dart';

void main() {
  group('HeartRateScenario', () {
    test('fromString 还原合法枚举名', () {
      expect(HeartRateScenario.fromString('low'), HeartRateScenario.low);
      expect(HeartRateScenario.fromString('medium'), HeartRateScenario.medium);
      expect(HeartRateScenario.fromString('high'), HeartRateScenario.high);
    });

    test('fromString 对 null 与未知值回退 medium', () {
      expect(HeartRateScenario.fromString(null), HeartRateScenario.medium);
      expect(HeartRateScenario.fromString(''), HeartRateScenario.medium);
      expect(HeartRateScenario.fromString('unknown'), HeartRateScenario.medium);
    });

    test('各档位基准值落在自身区间内', () {
      for (final scenario in HeartRateScenario.values) {
        expect(
          scenario.baseBpm,
          inInclusiveRange(scenario.minBpm, scenario.maxBpm),
          reason: '${scenario.name} 基准值应落在自身区间内',
        );
      }
    });

    test('三档区间按低中高递增且不重叠', () {
      final low = HeartRateScenario.low;
      final medium = HeartRateScenario.medium;
      final high = HeartRateScenario.high;

      expect(low.maxBpm, lessThanOrEqualTo(medium.minBpm));
      expect(medium.maxBpm, lessThan(high.minBpm));
    });
  });
}
