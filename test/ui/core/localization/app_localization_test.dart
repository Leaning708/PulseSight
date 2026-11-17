import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/ui/core/localization/app_localization.dart';

/// 在给定系统语言下渲染与主入口相同的本地化配置,返回解析出的 locale。
Future<Locale> _resolvedLocale(
  WidgetTester tester,
  List<Locale> platformLocales,
) async {
  tester.binding.platformDispatcher.localesTestValue = platformLocales;
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

  late Locale locale;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalization.delegates,
      supportedLocales: AppLocalization.supportedLocales,
      home: Builder(
        builder: (context) {
          locale = Localizations.localeOf(context);
          return const SizedBox();
        },
      ),
    ),
  );
  // 本地化代理加载完成后重建一次。
  await tester.pump();
  return locale;
}

void main() {
  group('AppLocalization', () {
    testWidgets('系统语言为简体中文时解析为 zh_CN', (tester) async {
      final locale = await _resolvedLocale(tester, const [Locale('zh', 'CN')]);

      expect(locale, const Locale('zh', 'CN'));
    });

    testWidgets('系统语言为英文时解析为 en', (tester) async {
      final locale = await _resolvedLocale(tester, const [Locale('en', 'US')]);

      expect(locale.languageCode, 'en');
    });

    testWidgets('系统语言为繁体中文时回落到简体中文', (tester) async {
      final locale = await _resolvedLocale(tester, const [Locale('zh', 'TW')]);

      expect(locale, const Locale('zh', 'CN'));
    });
  });
}
