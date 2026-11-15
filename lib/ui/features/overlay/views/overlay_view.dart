import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/heart_rate_history.dart';
import '../../../../domain/models/overlay_style.dart';
import '../../../core/widgets/bpm_display.dart';
import '../../../core/widgets/heart_rate_chart.dart';
import '../../../core/widgets/heartbeat_heart.dart';
import '../../../core/widgets/heartbeat_pulse.dart';

/// 悬浮窗内容:红心 + 心率数字,按 [style] 布局,三端复用。
///
/// 心形与心率数字共享同一脉冲动画(同步律动)。
/// [onPanStart] / [onTap] 由宿主注入:
/// 桌面悬浮窗用 [onPanStart] 触发系统级窗口拖动,穿透开启时不回调。
class OverlayView extends StatelessWidget {
  /// 创建悬浮窗内容;[style] 缺省为默认样式。
  const OverlayView({
    super.key,
    required this.bpm,
    required this.connected,
    this.style = OverlayStyle.defaults,
    required this.history,
    this.onPanStart,
    this.onTap,
  });

  /// 当前心率;为 null 时显示灰心与 “--”。
  final int? bpm;

  /// 是否处于连接状态(仅用于灰心判定,数据以 [bpm] 为准)。
  final bool connected;

  /// 显示样式。
  final OverlayStyle style;

  /// 近期心率采样历史(供折线图使用)。
  final HeartRateHistory history;

  /// 拖动开始回调(桌面端启动系统窗口拖动)。
  final VoidCallback? onPanStart;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 数字字重:由数值映射到 FontWeight。
  FontWeight get _numberWeight => FontWeight
      .values[(style.textWeight / 100).round().clamp(1, 9) - 1];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: onPanStart == null ? null : (_) => onPanStart!(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        // 背景板:颜色与透明度均可调;透明度 0 = 无背景板(纯透明)。
        // 背景板尺寸由样式决定,与悬浮窗窗口一致;内容超出时等比缩小。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: style.backgroundWidth,
            height: style.backgroundHeight,
            decoration: BoxDecoration(
              color: style.backgroundColor.withValues(
                alpha: style.backgroundOpacity.clamp(0.0, 1.0),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Opacity(
              opacity: style.opacity.clamp(0.1, 1.0),
              child: HeartbeatPulse(
                bpm: connected ? bpm : null,
                builder: (context, pulse, phase) {
                  final theme = Theme.of(context);
                  final heart = HeartbeatHeart(
                    size: style.heartSize,
                    bpm: connected ? bpm : null,
                    ecgStyle: style.ecgStyle,
                    heartColor: style.heartColor,
                    ecgColor: style.ecgColor,
                    pulsePhase: style.heartPulseEnabled ? phase : 0.0,
                    heartPulseEnabled: style.heartPulseEnabled,
                    glowRadius: style.glowRadius,
                    glowOpacity: style.glowOpacity,
                  );
                  final shadow = Shadow(
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.6),
                  );
                  final numberStyle = theme.textTheme.titleLarge?.copyWith(
                    fontSize: style.bpmFontSize,
                    fontWeight: _numberWeight,
                    fontFamily: style.textFontFamily,
                    color: style.textColor,
                    fontFeatures: [const FontFeature.tabularFigures()],
                    shadows: [shadow],
                  );
                  final labelStyle = theme.textTheme.labelSmall?.copyWith(
                    color: style.textColor.withValues(alpha: 0.7),
                    shadows: [shadow],
                  );
                  final bpmContent = BpmDisplay(
                    bpm: bpm,
                    axis: _bpmAxis,
                    showLabel: style.showBpmLabel,
                    numberStyle: numberStyle,
                    labelStyle: labelStyle,
                  );
                  // 文字律动可关:关闭时数字静止(不参与脉冲缩放)。
                  final bpmWidget = style.textPulseEnabled
                      ? ScaleTransition(scale: pulse, child: bpmContent)
                      : bpmContent;

                  final Widget content;
                  switch (style.bpmPosition) {
                    case BpmPosition.top:
                      content = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          bpmWidget,
                          SizedBox(height: style.gap),
                          heart,
                        ],
                      );
                    case BpmPosition.left:
                      content = Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          bpmWidget,
                          SizedBox(width: style.gap),
                          heart,
                        ],
                      );
                    case BpmPosition.right:
                      content = Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          heart,
                          SizedBox(width: style.gap),
                          bpmWidget,
                        ],
                      );
                    case BpmPosition.hidden:
                      content = heart;
                    case BpmPosition.bottom:
                      content = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          heart,
                          SizedBox(height: style.gap),
                          bpmWidget,
                        ],
                      );
                  }

                  final contentBlock = FittedBox(
                    fit: BoxFit.scaleDown,
                    child: content,
                  );

                  // 折线图固定在底部,心形与数字占上方区域。
                  return Column(
                    children: [
                      Expanded(
                        child: Center(child: contentBlock),
                      ),
                      if (style.showChart)
                        Padding(
                          padding: EdgeInsets.fromLTRB(8, style.chartSpacing, 8, 8),
                          child: SizedBox(
                            height: style.chartHeight,
                            width: double.infinity,
                            child: HeartRateChart(
                              values: history.values,
                              lineColor: style.chartLineColor,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 数字标签的排列方向:左右位置用竖排,上下位置用横排。
  Axis get _bpmAxis =>
      style.bpmPosition == BpmPosition.left || style.bpmPosition == BpmPosition.right
          ? Axis.vertical
          : Axis.horizontal;
}
