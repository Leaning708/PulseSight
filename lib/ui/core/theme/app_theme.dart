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

  /// 中文字体回退链(按平台优先级排列)。
  ///
  /// 主题主字体是 Roboto 等拉丁字体,不含汉字;不显式给出回退链时,
  /// 中文由 Skia 按 locale 自行挑选,可能出现简繁/粗细混排。这里固定
  /// 中文回退到各平台的系统界面字体,拉丁字形仍由主字体负责。
  static const List<String> cjkFontFamilyFallback = <String>[
    'Microsoft YaHei UI', // Windows
    'Microsoft YaHei',
    'PingFang SC', // macOS
    'Noto Sans CJK SC', // Linux / Android
    'Noto Sans SC',
    'Source Han Sans SC',
  ];

  /// 浅色主题。
  static ThemeData get light => _build(Brightness.light);

  /// 深色主题。
  static ThemeData get dark => _build(Brightness.dark);

  /// 带全局字体的浅色主题;[fontFamily] 为 null 时使用系统默认字体。
  static ThemeData lightWithFont(String? fontFamily) =>
      _build(Brightness.light, fontFamily: fontFamily);

  /// 带全局字体的深色主题;[fontFamily] 为 null 时使用系统默认字体。
  static ThemeData darkWithFont(String? fontFamily) =>
      _build(Brightness.dark, fontFamily: fontFamily);

  /// 浅色主题的中性画布色:比纯白更柔和,让白色面板卡片有层次。
  static const Color _lightCanvas = Color(0xFFF4F4F6);

  /// 深色主题的中性画布色。
  static const Color _darkCanvas = Color(0xFF111114);

  /// 由种子色派生并中性化的配色方案。
  ///
  /// 种子色只用来决定强调色与次要容器色;**中性表面色一律由本文件显式
  /// 指定**,避免 Material 3 的surface tint 把整块界面染成粉红 / 红棕,
  /// 也让深浅两套主题的面板层次可预期。
  static ColorScheme schemeFor(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.dark) {
      // 中性化深色表面,避免种子色染出的红棕底,让红色辉光更突出。
      return base.copyWith(
        primary: const Color(0xFFFF8A80),
        onPrimary: const Color(0xFF3A0A08),
        primaryContainer: const Color(0xFF5C1F1B),
        onPrimaryContainer: const Color(0xFFFFDAD5),
        surface: _darkCanvas,
        onSurface: const Color(0xFFE8E8EA),
        onSurfaceVariant: const Color(0xFFA9AAB0),
        surfaceContainerLowest: const Color(0xFF0E0E10),
        surfaceContainerLow: const Color(0xFF1D1E22),
        surfaceContainer: const Color(0xFF222327),
        surfaceContainerHigh: const Color(0xFF27282C),
        surfaceContainerHighest: const Color(0xFF343539),
        outline: const Color(0xFF56575C),
        outlineVariant: const Color(0xFF3A3B40),
      );
    }
    // 浅色:降低种子色带来的粉色调,表面保持中性灰白。
    return base.copyWith(
      primary: const Color(0xFFC62828),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFFFDAD5),
      onPrimaryContainer: const Color(0xFF410000),
      secondary: const Color(0xFF775650),
      surface: _lightCanvas,
      onSurface: const Color(0xFF1B1B1D),
      onSurfaceVariant: const Color(0xFF5E5F63),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFFFFFFF),
      surfaceContainer: const Color(0xFFF7F7F8),
      surfaceContainerHigh: const Color(0xFFEDEDEF),
      surfaceContainerHighest: const Color(0xFFE3E3E6),
      outline: const Color(0xFF8A8B90),
      outlineVariant: const Color(0xFFDCDCE0),
    );
  }

  /// 面板卡片底色(画布之上的一层)。
  static Color panelColor(ColorScheme scheme) => scheme.surfaceContainerLow;

  /// 面板卡片描边色。
  static Color panelBorderColor(ColorScheme scheme) => scheme.outlineVariant
      .withValues(alpha: scheme.brightness == Brightness.dark ? 0.7 : 1);

  static ThemeData _build(Brightness brightness, {String? fontFamily}) {
    final scheme = schemeFor(brightness);

    final panelBorder = BorderSide(color: panelBorderColor(scheme));

    // AppBar:与画布同色、无阴影、左对齐标题,靠字重建立层级而不是靠色块。
    final appBarTheme = AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AppSpacing.xl,
      titleTextStyle:
          (brightness == Brightness.dark
                  ? Typography.material2021().white
                  : Typography.material2021().black)
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: scheme.onSurface,
              ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    );

    // 排版:在默认 Material 3 字体度量上仅调整字重与字距,字体族由
    // ThemeData.fontFamily / fontFamilyFallback 统一注入(全局字体设置)。
    final typography = Typography.material2021();
    final baseText =
        (brightness == Brightness.dark ? typography.white : typography.black)
            .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final textTheme = baseText.copyWith(
      displayMedium: baseText.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      // 中文固定走系统界面字体,避免运行时随机回退导致中英混排风格不一致。
      fontFamilyFallback: cjkFontFamilyFallback,
      // 字体族在 textTheme 上就地注入:显式传入的 textTheme 会让 ThemeData
      // 跳过 fontFamily 的应用,导致全局字体设置对文本主题无效。
      textTheme: textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: cjkFontFamilyFallback,
      ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: appBarTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          // 紧凑分段:去掉 M3 默认的大内边距与勾选图标,等分宽度。
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontSize: 13),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: panelBorder.color)),
        ),
      ),
      // 开关:M3 默认的关闭态是「浅灰轨道 + 浅灰滑块」,在中性表面上几乎
      // 看不出形状。这里显式指定两态配色,保证关闭态也能看清控件。
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
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
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        inactiveTrackColor: scheme.surfaceContainerHighest,
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
