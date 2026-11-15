import 'package:material_ui/material_ui.dart';

import '../theme/app_dimens.dart';

/// 桌面面板卡片:圆角表面 + 标题(可选副标题 / 尾部控件)+ 内容。
///
/// 视觉样式来自主题的 [CardTheme],浅深色主题自适应。
class AppPanel extends StatelessWidget {
  /// 创建面板;[title] 必填,[child] 为面板内容。
  const AppPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.headerTrailing,
    required this.child,
    this.padding,
  });

  /// 面板标题。
  final String title;

  /// 标题下方的说明文字;null 时不渲染。
  final String? subtitle;

  /// 标题行尾部的控件(如开关、按钮);null 时不渲染。
  final Widget? headerTrailing;

  /// 面板内容。
  final Widget child;

  /// 内容区 EdgeInsets;缺省为 [AppSpacing.allXL]。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: padding ?? AppSpacing.allXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                ?headerTrailing,
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}
