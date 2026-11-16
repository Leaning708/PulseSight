import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/ui/core/widgets/setting_row.dart';

void main() {
  /// 渲染一行设置项。
  Future<void> pumpRow(
    WidgetTester tester, {
    required bool enabled,
    Widget? trailing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingRow(
            icon: Icons.info_outline,
            title: '桌面悬浮窗',
            subtitle: const Text('说明文字'),
            enabled: enabled,
            trailing: trailing ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  testWidgets('禁用态内容不被 Opacity 图层包裹', (tester) async {
    await pumpRow(tester, enabled: false);

    // 回归点:`Opacity(<1)` 会为该行创建 saveLayer,Flutter Windows(Impeller)
    // 在存在该图层时会把其它字形画成错误变换(顶栏 ❤ 被挤成竖条并移位,
    // 切到含禁用行的页面必现)。禁用态必须用颜色 alpha 表达。
    for (final finder in [
      find.text('桌面悬浮窗'),
      find.text('说明文字'),
      find.byIcon(Icons.info_outline),
    ]) {
      expect(
        find.ancestor(of: finder, matching: find.byType(Opacity)),
        findsNothing,
        reason: '禁用行内的内容不应处于 Opacity 图层之下',
      );
    }
  });

  testWidgets('禁用态文字与图标仍变暗(alpha 降低)', (tester) async {
    await pumpRow(tester, enabled: false);

    final title = tester.widget<Text>(find.text('桌面悬浮窗'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(title.style?.color?.a, lessThan(1.0), reason: '标题应降透明度');
    expect(icon.color?.a, lessThan(1.0), reason: '图标应降透明度');
  });

  testWidgets('可用态文字为正常不透明度', (tester) async {
    await pumpRow(tester, enabled: true);

    final title = tester.widget<Text>(find.text('桌面悬浮窗'));
    expect(title.style?.color?.a, 1.0);
  });

  testWidgets('禁用态不响应点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingRow(
            title: '不可用行',
            trailing: const SizedBox.shrink(),
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SettingRow));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('尾部开关由自身禁用配色表达,不额外包裹图层', (tester) async {
    await pumpRow(
      tester,
      enabled: false,
      trailing: const Switch(value: false, onChanged: null),
    );

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull);
    expect(
      find.ancestor(of: find.byType(Switch), matching: find.byType(Opacity)),
      findsNothing,
      reason: '开关不应被整行 Opacity 图层包裹',
    );
  });
}
