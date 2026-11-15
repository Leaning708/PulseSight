import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/platform/font_list_service.dart';

void main() {
  group('FontListService', () {
    test('懒加载:未加载前返回空列表,加载后缓存结果', () async {
      var callCount = 0;
      final service = FontListService(
        loader: () async {
          callCount++;
          return ['Microsoft YaHei', 'Arial'];
        },
      );

      expect(service.fontFamilies, isEmpty, reason: '加载完成前返回空列表');

      await service.load();
      expect(callCount, 1);
      expect(service.fontFamilies, ['Arial', 'Microsoft YaHei']);
      await service.ready;
    });

    test('去重并按大小写不敏感排序', () async {
      final service = FontListService(
        loader: () async => [
          'Microsoft YaHei',
          'Arial',
          'Microsoft YaHei',
          'SimSun',
        ],
      );

      await service.load();
      expect(service.fontFamilies, ['Arial', 'Microsoft YaHei', 'SimSun']);
    });

    test('排序不受大小写影响', () async {
      final service = FontListService(
        loader: () async => ['microsoft yahei', 'Arial', 'SimSun'],
      );

      await service.load();
      expect(service.fontFamilies, ['Arial', 'microsoft yahei', 'SimSun']);
    });

    test('重复 load 只调用一次 loader', () async {
      var callCount = 0;
      final service = FontListService(
        loader: () async {
          callCount++;
          return ['Arial'];
        },
      );

      await service.load();
      await service.load();
      expect(callCount, 1);
      expect(service.fontFamilies, ['Arial']);
    });

    test('loader 抛异常时静默降级为空列表,ready 正常完成', () async {
      final service = FontListService(
        loader: () async => throw StateError('boom'),
      );

      await service.load();
      expect(service.fontFamilies, isEmpty);
      await service.ready;
    });
  });
}
