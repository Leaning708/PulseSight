import 'package:material_ui/material_ui.dart';

import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';

/// 主界面分区标题:小号大写感标签 + 可选尾部控件。
///
/// 与 [AppCard] 配合建立「区块标题 → 卡片」的两级层次,替代原先
/// 散落在页面里的纯文本标题与分隔线。
class SectionHeader extends StatelessWidget {
  /// 创建分区标题;[title] 必填。
  const SectionHeader({super.key, required this.title, this.trailing});

  /// 分区标题文字。
  final String title;

  /// 标题行尾部控件(如「恢复默认」按钮);null 时不渲染。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 分组卡片:圆角面板 + 可选图标标题 + 内容,条目之间用细分隔线。
///
/// 视觉样式取自主题(中性表面 + 极淡描边),深浅主题自适应。
class AppCard extends StatelessWidget {
  /// 创建分组卡片;[child] 为卡片内容。
  const AppCard({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  /// 标题前的图标;null 时不渲染。
  final IconData? icon;

  /// 卡片标题;null 时省略标题行(内容直接铺满)。
  final String? title;

  /// 标题下方的说明文字。
  final String? subtitle;

  /// 标题行尾部控件。
  final Widget? trailing;

  /// 卡片内容。
  final Widget child;

  /// 内容内边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHeader = title != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.panelColor(scheme),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppTheme.panelBorderColor(scheme)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleSmall,
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
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// 卡片内的条目分隔线:左右内缩,避免与卡片圆角打架。
class CardDivider extends StatelessWidget {
  /// 创建分隔线。
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.7),
    );
  }
}
