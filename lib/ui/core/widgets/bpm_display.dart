import 'package:material_ui/material_ui.dart';

/// bpm 数值展示:大号数字 + 可选的 “bpm” 标签。
class BpmDisplay extends StatelessWidget {
  /// 创建数值展示;[bpm] 为 null 时显示 “--”。
  const BpmDisplay({
    super.key,
    required this.bpm,
    this.axis = Axis.horizontal,
    this.showLabel = true,
    this.numberStyle,
    this.labelStyle,
    this.spacing = 4.0,
  });

  /// 当前心率;为 null 表示暂无数据。
  final int? bpm;

  /// 数字与标签的排列方向。
  final Axis axis;

  /// 是否显示 “bpm” 标签。
  final bool showLabel;

  /// 数字样式。
  final TextStyle? numberStyle;

  /// “bpm” 标签样式。
  final TextStyle? labelStyle;

  /// 数字与标签的间距。
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = Text(
      bpm?.toString() ?? '--',
      style:
          numberStyle ??
          theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: bpm == null
                ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                : null,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
    );
    if (!showLabel) {
      return number;
    }
    final label = Text(
      'bpm',
      style:
          labelStyle ??
          theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
    );
    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          number,
          SizedBox(height: spacing),
          label,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        number,
        SizedBox(width: spacing),
        label,
      ],
    );
  }
}
