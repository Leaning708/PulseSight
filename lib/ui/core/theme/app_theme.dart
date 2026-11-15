import 'package:material_ui/material_ui.dart';

import 'app_dimens.dart';

/// 应用主题。
abstract final class AppTheme {
  /// 主色:心率红。
  static const Color seedColor = Color(0xFFE53935);

  /// 红心渐变的亮部。
  static const Color heartLight = Color(0xFFFF6B6B);

  /// 红心渐变的暗部。
  static const Color heartDeep = Color(0xFFE23A3A);

  /// 未连接时的灰心颜色。
  static const Color heartIdle = Color(0xFF9E9E9E);

  /// 「监视器」舞台底色:深色,浅 / 深主题通用,衬托红心辉光,
  /// 与悬浮窗预览容器保持一致。
  static const Color stageColor = Color(0xFF17181C);

  /// 浅色主题。
  static ThemeData get light => _build(Brightness.light);

  /// 深色主题。
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    var scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.dark) {
      // 中性化深色表面,避免种子色染出的红棕底,让红色辉光更突出。
      scheme = scheme.copyWith(
        surface: const Color(0xFF141416),
        surfaceContainerLowest: const Color(0xFF101012),
        surfaceContainerLow: const Color(0xFF1B1C1F),
        surfaceContainer: const Color(0xFF212226),
        surfaceContainerHigh: const Color(0xFF2A2B2F),
        surfaceContainerHighest: const Color(0xFF343539),
      );
    }

    final panelBorder = BorderSide(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? scheme.surface
          : null,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: panelBorder,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      // 桌面端悬浮滚动条:细条、无轨道,避免遮盖贴边内容。
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStatePropertyAll(
          scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        radius: const Radius.circular(3),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
        minThumbLength: 48,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
