import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/domain/models/heart_rate_history.dart';

void main() {
  group('HeartRateHistory', () {
    test('add 追加采样并保持时间升序', () {
      final history = HeartRateHistory();
      history.add(72);
      history.add(75);
      history.add(78);

      expect(history.values, [72, 75, 78]);
      expect(history.hasEnoughData, isTrue);
    });

    test('超出 maxLength 时移除最旧数据', () {
      final history = HeartRateHistory(maxLength: 3);
      for (var bpm in [60, 65, 70, 75, 80]) {
        history.add(bpm);
      }

      expect(history.values, [70, 75, 80]);
    });

    test('clear 清空全部数据', () {
      final history = HeartRateHistory(maxLength: 3);
      history.add(70);
      history.add(75);
      history.clear();

      expect(history.values, isEmpty);
      expect(history.hasEnoughData, isFalse);
    });

    test('单个采样点不足以绘制折线', () {
      final history = HeartRateHistory();
      history.add(72);

      expect(history.hasEnoughData, isFalse);
    });
  });
}
