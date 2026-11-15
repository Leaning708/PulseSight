import 'package:material_ui/material_ui.dart';

import 'heartbeat_heart.dart';

/// 共享心跳脉冲动画组件。
///
/// 按 [bpm] 频率驱动单次脉冲缩放动画(周期 = 60s/bpm),并通过
/// [builder] 把脉冲动画与周期相位交给外部,使心形与心率文字等元素
/// 能共享同一动画实现同步律动。
///
/// [bpm] 为 null(未连接/断连)时动画静止,脉冲保持在 1.0。
class HeartbeatPulse extends StatefulWidget {
  /// 创建脉冲动画组件。
  const HeartbeatPulse({
    super.key,
    required this.bpm,
    required this.builder,
  });

  /// 当前心率;为 null 时动画静止。
  final int? bpm;

  /// 构建回调;[pulse] 为脉冲缩放动画(1.0 = 原始大小,可直接用于
  /// ScaleTransition 等),[phase] 为心跳周期相位(0~1)。
  final Widget Function(
      BuildContext context,
      Animation<double> pulse,
      double phase) builder;

  @override
  State<HeartbeatPulse> createState() => _HeartbeatPulseState();
}

class _HeartbeatPulseState extends State<HeartbeatPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HeartbeatHeart.beatDuration(widget.bpm),
  );

  late final Animation<double> _pulse =
      HeartbeatHeart.pulseSequence().animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.bpm != null) _controller.repeat();
  }

  @override
  void didUpdateWidget(HeartbeatPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.bpm != null;
    final isActive = widget.bpm != null;
    if (widget.bpm != oldWidget.bpm) {
      _controller.duration = HeartbeatHeart.beatDuration(widget.bpm);
    }
    if (isActive && !wasActive) {
      _controller.repeat();
    } else if (!isActive && wasActive) {
      // 断连:复位到原始大小并停止。
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) =>
          widget.builder(context, _pulse, _controller.value),
    );
  }
}
