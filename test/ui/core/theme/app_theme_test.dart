import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/ui/core/theme/app_dimens.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('浅色主题为浅色方案并启用 Material 3', () {
      final theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('深色主题为深色方案且脚手架背景中性化', () {
      final theme = AppTheme.dark;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      // 表面中性化:不再由种子色染出红棕底。
      expect(theme.colorScheme.surface.toARGB32(), 0xFF141416);
    });

    test('深浅主题的面板卡片统一样式', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final cardTheme = theme.cardTheme;
        expect(cardTheme.elevation, 0);
        expect(cardTheme.margin, EdgeInsets.zero);
        final shape = cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, AppRadius.cardBorder);
        expect(shape.side, isNot(BorderSide.none));
      }
    });

    test('SnackBar 保持浮动样式', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      }
    });
  });

  group('AppDimens', () {
    test('间距与圆角令牌取值稳定', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 20);
      expect(AppSpacing.xxl, 24);
      expect(AppSpacing.xxxl, 32);
      expect(AppRadius.card, 16);
      expect(AppRadius.control, 12);
    });
  });
}
