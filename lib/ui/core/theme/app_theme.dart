import 'package:material_ui/material_ui.dart';

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

  /// 浅色主题。
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
