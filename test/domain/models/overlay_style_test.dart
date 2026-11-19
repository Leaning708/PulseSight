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
      expect(style.heartTextGap, 6);
      expect(style.glowEnabled, isTrue);
    });

    test('辉光开关随样式保存与还原', () {
      const style = OverlayStyle.defaults;
      final off = style.copyWith(glowEnabled: false);

      expect(off.glowEnabled, isFalse);
      // 关闭辉光不影响半径/透明度取值,重新打开即恢复原样。
      expect(off.glowRadius, style.glowRadius);
      expect(off.glowOpacity, style.glowOpacity);
      expect(OverlayStyle.fromJson(off.toJson()).glowEnabled, isFalse);
      expect(OverlayStyle.fromJson(off.toJson()), off);
    });

    test('copyWith 仅替换指定字段', () {
      const style = OverlayStyle.defaults;
      final updated = style.copyWith(heartSize: 80, ecgStyle: EcgStyle.flat);

      expect(updated.heartSize, 80);
      expect(updated.ecgStyle, EcgStyle.flat);
      expect(updated.bpmFontSize, style.bpmFontSize);
      expect(updated.bpmPosition, style.bpmPosition);
      expect(updated.heartTextGap, style.heartTextGap);
    });

    test('copyWith 可将 textFontFamily 置回 null(切回系统默认)', () {
      const style = OverlayStyle(bpmFontFamily: 'Microsoft YaHei');

      // 不带 clear 参数时保留原值(copyWith 不应误清空)。
      expect(style.copyWith().bpmFontFamily, 'Microsoft YaHei');
      // 选择“默认(系统)”时显式清空。
      expect(style.copyWith(clearBpmFontFamily: true).bpmFontFamily, isNull);
    });

    test('textFontFamily 序列化往返一致,缺键回退 null', () {
      const style = OverlayStyle(bpmFontFamily: '微软雅黑');
      final restored = OverlayStyle.fromJson(style.toJson());

      expect(restored.bpmFontFamily, '微软雅黑');
      expect(restored, style);

      final missing = OverlayStyle.fromJson(<dynamic, dynamic>{});
      expect(missing.bpmFontFamily, isNull);
    });

    test('toJson/fromJson 往返一致', () {
      const style = OverlayStyle(
        heartSize: 90,
        bpmFontSize: 30,
        bpmPosition: BpmPosition.left,
        ecgStyle: EcgStyle.single,
        heartTextGap: 12,
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
      expect(
        const OverlayStyle(heartSize: 80),
        const OverlayStyle(heartSize: 80),
      );
      expect(
        const OverlayStyle(heartSize: 80),
        isNot(const OverlayStyle(heartSize: 64)),
      );
    });
  });
}
