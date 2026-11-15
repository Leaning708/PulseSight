import 'package:material_ui/material_ui.dart';

/// 设计令牌:统一间距。
abstract final class AppSpacing {
  /// 4。
  static const double xs = 4;

  /// 8。
  static const double sm = 8;

  /// 12。
  static const double md = 12;

  /// 16。
  static const double lg = 16;

  /// 20。
  static const double xl = 20;

  /// 24。
  static const double xxl = 24;

  /// 32。
  static const double xxxl = 32;

  /// 水平对称 [AppSpacing.xxl] 的 EdgeInsets。
  static const EdgeInsets hXXL = EdgeInsets.symmetric(horizontal: xxl);

  /// 全方向 [AppSpacing.xl] 的 EdgeInsets。
  static const EdgeInsets allXL = EdgeInsets.all(xl);
}

/// 设计令牌:统一圆角。
abstract final class AppRadius {
  /// 面板卡片圆角(16)。
  static const double card = 16;

  /// 控件圆角(12)。
  static const double control = 12;

  /// [AppRadius.card] 的 BorderRadius。
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );

  /// [AppRadius.control] 的 BorderRadius。
  static const BorderRadius controlBorder = BorderRadius.all(
    Radius.circular(control),
  );
}

/// 主界面窄布局的宽度上限(手机布局保持居中窄列)。
const double homeNarrowMaxWidth = 480;

/// 桌面设置式布局的最小窗口宽度;低于该值退化为窄布局。
const double desktopBreakpoint = 720;

/// 桌面左侧导航栏宽度。
const double desktopNavRailWidth = 200;

/// 桌面详情面板内容的宽度上限(过宽时居中,避免控件行拉长)。
const double desktopPaneMaxWidth = 720;
