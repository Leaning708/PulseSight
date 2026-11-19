import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/core/widgets/font_family_field.dart';

void main() {
  const families = ['Al Bayan', 'Menlo', 'PingFang SC', 'Roboto Mono'];

  /// 渲染一个带默认值的字体选择入口。
  Future<void> pumpField(WidgetTester tester, {String? value = 'Menlo'}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: FontFamilyField(
                fieldKey: const Key('font_field'),
                value: value,
                fontFamilies: families,
                emptyLabel: '跟随全局(系统默认)',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('触发器展示当前字体,点击后弹出带搜索的列表', (tester) async {
    await pumpField(tester);

    expect(find.text('Menlo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('font_field')));
    await tester.pumpAndSettle();

    expect(find.text('选择字体'), findsOneWidget);
    expect(find.byKey(const Key('font_picker_search')), findsOneWidget);
    // 默认项 + 全部字体都在列表里。
    expect(find.text('跟随全局(系统默认)'), findsOneWidget);
    expect(find.text('4 个字体'), findsOneWidget);
  });

  testWidgets('搜索按名称过滤,未命中显示空态', (tester) async {
    await pumpField(tester);
    await tester.tap(find.byKey(const Key('font_field')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('font_picker_search')), 'mono');
    await tester.pumpAndSettle();

    expect(find.text('Roboto Mono'), findsOneWidget);
    expect(find.text('Al Bayan'), findsNothing);
    // 搜索时不再展示「默认」项。
    expect(find.text('跟随全局(系统默认)'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('font_picker_search')),
      '不存在的字体',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的字体'), findsOneWidget);
  });

  testWidgets('选择字体后回调新值', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FontFamilyField(
            fieldKey: const Key('font_field'),
            value: null,
            fontFamilies: families,
            emptyLabel: '跟随全局(系统默认)',
            onChanged: (value) => picked = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('font_field')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PingFang SC'));
    await tester.pumpAndSettle();

    expect(picked, 'PingFang SC');
  });

  testWidgets('取消不触发回调', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FontFamilyField(
            fieldKey: const Key('font_field'),
            value: 'Menlo',
            fontFamilies: families,
            emptyLabel: '跟随全局(系统默认)',
            onChanged: (_) => called = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('font_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });
}
