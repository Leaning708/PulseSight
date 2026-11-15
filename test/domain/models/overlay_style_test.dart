import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';

void main() {
  group('OverlayStyle', () {
    test('默认值正确', () {
      const style = OverlayStyle.defaults;
      expect(style.heartSize, 64);
      expect(style.bpmFontSize, 20);
      expect(style.bpmPosition, BpmPosition.bottom);
      expect(style.ecgStyle, EcgStyle.classic);
      expect(style.gap, 6);
    });

    test('copyWith 仅替换指定字段', () {
      const style = OverlayStyle.defaults;
      final updated = style.copyWith(heartSize: 80, ecgStyle: EcgStyle.flat);

      expect(updated.heartSize, 80);
      expect(updated.ecgStyle, EcgStyle.flat);
      expect(updated.bpmFontSize, style.bpmFontSize);
      expect(updated.bpmPosition, style.bpmPosition);
      expect(updated.gap, style.gap);
    });

    test('toJson/fromJson 往返一致', () {
      const style = OverlayStyle(
        heartSize: 90,
        bpmFontSize: 30,
        bpmPosition: BpmPosition.left,
        ecgStyle: EcgStyle.single,
        gap: 12,
      );
      final restored = OverlayStyle.fromJson(style.toJson());

      expect(restored, style);
    });

    test('fromJson 非法/缺失字段回退默认值', () {
      final restored = OverlayStyle.fromJson(<dynamic, dynamic>{
        'heartSize': 'oops',
        'bpmPosition': 'diagonal',
        'ecgStyle': 'unknown',
      });

      expect(restored, OverlayStyle.defaults);
    });

    test('BpmPosition/EcgStyle.fromString 非法值回退默认', () {
      expect(BpmPosition.fromString('top'), BpmPosition.top);
      expect(BpmPosition.fromString('bogus'), BpmPosition.bottom);
      expect(BpmPosition.fromString(null), BpmPosition.bottom);
      expect(EcgStyle.fromString('single'), EcgStyle.single);
      expect(EcgStyle.fromString('bogus'), EcgStyle.classic);
      expect(EcgStyle.fromString(null), EcgStyle.classic);
    });

    test('相等性:字段相同则相等', () {
      expect(const OverlayStyle(heartSize: 80), const OverlayStyle(heartSize: 80));
      expect(
        const OverlayStyle(heartSize: 80),
        isNot(const OverlayStyle(heartSize: 64)),
      );
    });
  });
}
