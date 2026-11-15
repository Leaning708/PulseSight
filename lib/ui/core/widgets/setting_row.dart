import 'package:material_ui/material_ui.dart';

import '../theme/app_dimens.dart';

/// 桌面风设置行:图标 + 标题 / 说明 + 尾部控件。
///
/// 用于替代 Android 味较重的 SwitchListTile,标题与说明左对齐,
/// 尾部通常放置 Switch / 图标按钮;整行可响应点击。
class SettingRow extends StatelessWidget {
  /// 创建设置行;[title] 必填,[trailing] 通常为开关类控件。
  const SettingRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
    this.enabled = true,
  });

  /// 行首图标;null 时不渲染。
  final IconData? icon;

  /// 设置项标题。
  final String title;

  /// 标题下方的说明(可为富文本,如 OBS 地址行);null 时不渲染。
  final Widget? subtitle;

  /// 行尾控件。
  final Widget trailing;

  /// 整行点击回调(不含尾部控件);null 时不响应。
  final VoidCallback? onTap;

  /// 是否可用;不可用时整行降透明度且不响应。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alpha = enabled ? 1.0 : 0.5;
    return Opacity(
      opacity: alpha,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.controlBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
