import 'package:material_ui/material_ui.dart';

import '../theme/app_dimens.dart';

/// 状态胶囊:彩色圆点 + 状态文案(可选补充信息)。
///
/// 通用展示组件,颜色与文案由调用方决定。
class StatusPill extends StatelessWidget {
  /// 创建状态胶囊;[detail] 为圆点后的补充信息(如实时 bpm)。
  const StatusPill({
    super.key,
    required this.color,
    required this.label,
    this.detail,
  });

  /// 圆点颜色(通常为状态色)。
  final Color color;

  /// 状态文案。
  final String label;

  /// 补充信息,以「 · detail」拼接显示;null 时不渲染。
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(detail == null ? label : '$label · $detail', style: textStyle),
        ],
      ),
    );
  }
}
