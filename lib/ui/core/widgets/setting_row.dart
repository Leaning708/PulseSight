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

  /// 是否可用;不可用时文字与图标降透明度且整行不响应。
  ///
  /// 注意:禁用态**不用 [Opacity] 表达**。`Opacity(<1)` 会为该行创建一个
  /// saveLayer 合成图层;Windows 上 Impeller 在存在该图层时会把其它文字/
  /// 图标字形画成错误变换(实测:顶栏 ❤ 被挤成竖条并移位)。这里改为按颜色
  /// alpha 变暗,不产生合成图层。同类问题已在渲染后端层面统一规避
  /// (`windows/runner/main.cpp` 改用 Skia),此处仍保持无图层实现。
  final bool enabled;

  /// 禁用态的颜色衰减系数。
  static const double _disabledAlpha = 0.55;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // 按 alpha 变暗而不使用 Opacity 图层(见 [enabled] 说明)。
    Color fade(Color color) =>
        enabled ? color : color.withValues(alpha: color.a * _disabledAlpha);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: fade(scheme.onSurface),
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: fade(scheme.onSurfaceVariant),
    );
    return InkWell(
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
              Icon(icon, size: 20, color: fade(scheme.onSurfaceVariant)),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: subtitleStyle,
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
    );
  }
}
