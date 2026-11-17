import 'package:material_ui/material_ui.dart';

/// 应用的语言与本地化配置。
///
/// `WidgetsApp.supportedLocales` 默认只有 `en_US`:若不显式配置,
/// 即使系统语言是简体中文,`Localizations.localeOf` 也会解析成 `en_US`,
/// 中文文本的字形选择与字体回退随之按非中文 locale 进行,可能混入
/// 繁体 / 日文字形或出现粗细不一致(见 `docs/desktop-ui.md`「全局字体」)。
///
/// 代理取自 `material_ui` 的 `GlobalMaterialLocalizations.delegates`
/// (Material / Cupertino / Widgets 三层),而非 `flutter_localizations`
/// 的同名类:`material_ui` 自带一份 Material 实现,类型需与之匹配。
abstract final class AppLocalization {
  /// 支持的语言:简体中文优先,其次英文。
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh', 'CN'),
    Locale('en'),
  ];

  /// 本地化代理(Material / Cupertino / Widgets)。
  static const List<LocalizationsDelegate<dynamic>> delegates =
      GlobalMaterialLocalizations.delegates;
}
