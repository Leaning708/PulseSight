import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/heart_rate_measurement.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('解析 8 位心率值', () {
      // flags bit0 = 0,随后 1 字节心率。
      expect(parseHeartRateMeasurement([0x00, 72]), 72);
    });

    test('解析 16 位小端心率值', () {
      // flags bit0 = 1,随后 2 字节小端心率。
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]), 300);
      expect(parseHeartRateMeasurement([0x01, 0x80, 0x00]), 128);
    });

    test('忽略 flags 中的其它位', () {
      // bit1 传感器接触、bit3 能量消耗、bit4 RR 间期均与心率格式无关。
      expect(parseHeartRateMeasurement([0x1E, 66]), 66);
    });

    test('数据为空或长度不足时返回 null', () {
      expect(parseHeartRateMeasurement(const []), isNull);
      expect(parseHeartRateMeasurement(const [0x00]), isNull);
      expect(parseHeartRateMeasurement(const [0x01, 0x2C]), isNull);
    });
  });

  group('isValidHeartRate', () {
    test('过滤未佩戴时的 0 与异常大值', () {
      expect(isValidHeartRate(0), isFalse);
      expect(isValidHeartRate(72), isTrue);
      expect(isValidHeartRate(300), isTrue);
      expect(isValidHeartRate(301), isFalse);
    });
  });
}
