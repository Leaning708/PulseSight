import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../domain/models/overlay_style.dart';
import '../theme/app_theme.dart';

/// 随 bpm 节奏跳动的红心组件。
///
/// [bpm] 不为 null 时,红心按该频率做单次脉冲缩放(60bpm 即每秒跳一次),
/// 并按 [ecgStyle] 在心形内部播放心电图动画;
/// [bpm] 为 null 时显示静止的灰色空心态(未连接/无数据)。
/// [heartColor] 自定义心形颜色(渐变自动衍生),[ecgColor] 自定义心电图线颜色。
/// 传入 [pulsePhase](0~1,心跳周期相位)时以此驱动绘制(与文字等元素
/// 同步律动);不传则组件内部自驱动动画。
/// [heartPulseEnabled] 为 false 时心形静止(仅脉冲关闭,心电图动画照常);
/// [glowRadius]/[glowOpacity] 分别调节心跳辉光的半径与透明度。
/// 三端复用:主界面预览、桌面悬浮窗、Android 悬浮窗。
class HeartbeatHeart extends StatefulWidget {
  /// 创建红心;[size] 为绘制区域的边长。
  const HeartbeatHeart({
    super.key,
    required this.size,
    this.bpm,
    this.ecgStyle = EcgStyle.classic,
    this.heartColor = OverlayStyle.defaultHeartColor,
    this.ecgColor = OverlayStyle.defaultEcgColor,
    this.pulsePhase,
    this.heartPulseEnabled = true,
    this.glowRadius = 1.0,
    this.glowOpacity = 0.5,
  });

  /// 绘制区域边长(逻辑像素)。
  final double size;

  /// 当前心率;为 null 表示未连接或暂无数据。
  final int? bpm;

  /// 心电图样式。
  final EcgStyle ecgStyle;

  /// 心形颜色。
  final Color heartColor;

  /// 心电图线颜色。
  final Color ecgColor;

  /// 心跳周期相位(0~1);非 null 时外部驱动绘制,
  /// 与心率文字等元素共享同一动画实现同步律动。
  final double? pulsePhase;

  /// 心形是否脉冲缩放(关闭时心形静止)。
  final bool heartPulseEnabled;

  /// 心跳辉光强度(0 = 无辉光,1.0 = 默认)。
  /// 辉光半径倍率(0 = 无辉光)。
  final double glowRadius;

  /// 辉光透明度倍率(0.0 ~ 1.0)。
  final double glowOpacity;

  @override
  State<HeartbeatHeart> createState() => _HeartbeatHeartState();

  /// 根据 bpm 计算一次心跳的动画周期;[bpm] 无效时返回 800ms(未连接态不使用)。
  static Duration beatDuration(int? bpm) {
    if (bpm == null || bpm <= 0) return const Duration(milliseconds: 800);
    return Duration(milliseconds: (60 * 1000 / bpm).round());
  }

  /// 脉冲缩放序列:快速扩张 → 缓慢回落 → 静置至周期结束。
  static Animatable<double> pulseSequence() {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 32,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    ]);
  }

  /// 计算心形从 24 视窗映射到画布的布局参数:
  /// [s] 等比缩放系数,[dx]/[dy] 画布平移量。
  /// 该映射保证心形中心(24 视窗内 12, 12.175)恰好落在画布中心,
  /// 与脉冲缩放配合时跳动不会偏移。
  @visibleForTesting
  static ({double s, double dx, double dy}) layoutFor(Size size) {
    final s = size.width / 20 * 0.94;
    final dx = (size.width - 20 * s) / 2 - 2 * s;
    final dy = (size.height - 18.35 * s) / 2 - 3 * s;
    return (s: s, dx: dx, dy: dy);
  }
}

class _HeartbeatHeartState extends State<HeartbeatHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HeartbeatHeart.beatDuration(widget.bpm),
  );

  late final Animation<double> _scale =
      HeartbeatHeart.pulseSequence().animate(_controller);

  @override
  void didUpdateWidget(HeartbeatHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.bpm != null;
    final isActive = widget.bpm != null;
    if (widget.bpm != oldWidget.bpm) {
      _controller.duration = HeartbeatHeart.beatDuration(widget.bpm);
    }
    // 外部相位驱动模式下不启用内部控制器。
    if (widget.pulsePhase != null) return;
    if (isActive && !wasActive) {
      _controller.repeat();
    } else if (!isActive && wasActive) {
      // 断连:复位到原始大小并停止。
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.bpm != null && widget.pulsePhase == null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外部相位驱动:与文字等元素共享同一动画(同步律动)。
    if (widget.pulsePhase != null) {
      return _paintHeart(
        phase: widget.pulsePhase!,
        idle: widget.bpm == null,
      );
    }
    final disconnected = widget.bpm == null;
    if (disconnected) {
      return _paintHeart(phase: 0, idle: true);
    }
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) => _paintHeart(
        phase: _controller.value,
        idle: false,
      ),
    );
  }

  Widget _paintHeart({required double phase, required bool idle}) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _HeartPainter(
          phase: phase,
          showEcg: !idle && widget.ecgStyle != EcgStyle.none,
          ecgStyle: widget.ecgStyle,
          bpm: widget.bpm,
          heartColor: idle ? AppTheme.heartIdle : widget.heartColor,
          ecgColor: idle ? AppTheme.heartIdle : widget.ecgColor,
          heartPulseEnabled: widget.heartPulseEnabled,
          glowRadius: widget.glowRadius,
          glowOpacity: widget.glowOpacity,
        ),
      ),
    );
  }
}

/// 绘制心形路径:自定义色渐变 + 高光 + 心跳辉光 + 内部"被画出"的心电图线。
class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required this.phase,
    required this.showEcg,
    required this.ecgStyle,
    required this.bpm,
    required this.heartColor,
    required this.ecgColor,
    required this.heartPulseEnabled,
    required this.glowRadius,
    required this.glowOpacity,
  });

  /// 心跳周期相位(0~1),驱动脉冲缩放与心电图绘制进度。
  final double phase;

  /// 是否绘制心电图(未连接的灰心不绘制)。
  final bool showEcg;

  /// 心电图样式。
  final EcgStyle ecgStyle;

  /// 当前心率(digits 样式在心内显示)。
  final int? bpm;

  /// 心形主色(渐变暗部)。
  final Color heartColor;

  /// 心电图线颜色。
  final Color ecgColor;

  /// 心形是否脉冲缩放(关闭时心形静止)。
  final bool heartPulseEnabled;

  /// 心跳辉光强度倍率(0 = 无辉光)。
  /// 辉光半径倍率(0 = 无辉光)。
  final double glowRadius;

  /// 辉光透明度倍率(0.0 ~ 1.0)。
  final double glowOpacity;

  /// 脉冲缩放系数:脉冲关闭时恒为 1.0(心形静止),
  /// 开启时由相位经脉冲序列推导。
  double get _scale => heartPulseEnabled
      ? HeartbeatHeart.pulseSequence()
          .evaluate(AlwaysStoppedAnimation(phase))
      : 1.0;

  /// 渐变亮部:主色向白色插值。
  Color get _topColor =>
      Color.lerp(heartColor, const Color(0xFFFFFFFF), 0.28)!;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heartPath();
    final layout = HeartbeatHeart.layoutFor(size);
    final scale = _scale;

    canvas.save();
    canvas.translate(layout.dx, layout.dy);
    canvas.scale(layout.s, layout.s);
    // 脉冲缩放必须以心形中心(24 视窗内 12, 12.175)为原点,
    // 否则跳动会朝右下角偏移。
    canvas.translate(12, 12.175);
    canvas.scale(scale, scale);
    canvas.translate(-12, -12.175);

    if (scale > 1.0 && glowOpacity > 0 && glowRadius > 0) {
      // 双层辉光:内层亮辉光 + 外层大范围柔光;
      // 半径与透明度由两个独立滑块分别调节。
      final blur = (scale - 1.0) * 90 * glowRadius / (layout.s * scale);
      final glowAlpha = (0.45 * glowOpacity).clamp(0.0, 0.85);
      canvas.drawPath(
        path,
        Paint()
          ..color = heartColor.withValues(alpha: glowAlpha * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 2),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = heartColor.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    final rect = Rect.fromLTWH(2, 3, 20, 18.35);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_topColor, heartColor],
        ).createShader(rect),
    );

    // 左上高光,增加立体感。
    canvas.save();
    canvas
      ..translate(7.2, 7.0)
      ..rotate(-0.5)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: 4.6, height: 2.2),
        Paint()..color = const Color(0x59FFFFFF),
      );
    canvas.restore();

    if (showEcg) {
      _drawEcg(canvas, path);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) {
    return phase != oldDelegate.phase ||
        showEcg != oldDelegate.showEcg ||
        ecgStyle != oldDelegate.ecgStyle ||
        heartColor != oldDelegate.heartColor ||
        ecgColor != oldDelegate.ecgColor ||
        heartPulseEnabled != oldDelegate.heartPulseEnabled ||
        glowRadius != oldDelegate.glowRadius ||
        glowOpacity != oldDelegate.glowOpacity;
  }

  /// 在心形内部绘制"被画出"的心电图线(或 digits 样式的心内数字)。
  ///
  /// 波形位置固定(横向居中,横跨心形,R 尖峰在正中心),
  /// 每个心跳周期:从左侧被逐步"画"出来(占周期前 45%)→ 完整显示片刻 →
  /// 整体淡出消失(60%~90%)→ 静置至下一拍。
  /// digits 样式改为在心内淡入/淡出 BPM 数字。
  /// 用 [heartPath] 裁剪,使线只在心形内部可见。
  void _drawEcg(Canvas canvas, Path heartPath) {
    const drawEnd = 0.45;
    const holdEnd = 0.60;
    const fadeEnd = 0.90;

    double alpha;
    double drawProgress;
    if (phase < drawEnd) {
      alpha = 1.0;
      drawProgress = phase / drawEnd;
    } else if (phase < holdEnd) {
      alpha = 1.0;
      drawProgress = 1.0;
    } else if (phase < fadeEnd) {
      alpha = 1.0 - (phase - holdEnd) / (fadeEnd - holdEnd);
      drawProgress = 1.0;
    } else {
      return; // 静置期,不绘制。
    }

    canvas.save();
    canvas.clipPath(heartPath);

    // digits 样式:在心内直接绘制 BPM 数字(随绘制进度淡入)。
    if (ecgStyle == EcgStyle.digits) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${bpm ?? "--"}',
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            color: ecgColor.withValues(alpha: 0.9 * alpha * drawProgress),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(12 - tp.width / 2, _ecgBaseline - tp.height / 2),
      );
      canvas.restore();
      return;
    }

    // 完整波形路径(横向居中,R 尖峰位于心形中心)。
    const startX = 3.0;
    const span = 18.0;
    final wave = Path();
    if (ecgStyle == EcgStyle.flat) {
      // 平直基线:一条横贯心形的直线,同样参与"画出"动画。
      wave.moveTo(startX, _ecgBaseline);
      wave.lineTo(startX + span, _ecgBaseline);
    } else {
      var first = true;
      for (var x = startX; x <= startX + span; x += 0.25) {
        final u = (x - startX) / span;
        final y = _ecgBaseline + _ecgWave(ecgStyle, u);
        if (first) {
          wave.moveTo(x, y);
          first = false;
        } else {
          wave.lineTo(x, y);
        }
      }
    }

    // 用 PathMetrics 按 drawProgress 修剪出"已画出"的部分。
    final metrics = wave.computeMetrics().toList();
    if (metrics.isEmpty) {
      canvas.restore();
      return;
    }
    final metric = metrics.first;
    final visible =
        metric.extractPath(0, metric.length * drawProgress.clamp(0.0, 1.0));

    // 柔光描边,制造霓虹质感。
    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = ecgColor.withValues(alpha: 0.30 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = ecgColor.withValues(alpha: 0.85 * alpha)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  /// 心电图基线(24 视窗内的心形中心)。
  static const double _ecgBaseline = 12.175;

  /// 余弦圆顶波:在 [center - halfWidth, center + halfWidth] 内平滑隆起。
  double _bump(double u, double center, double halfWidth, double amplitude) {
    final d = (u - center).abs();
    if (d >= halfWidth) return 0;
    return amplitude * 0.5 * (1 + math.cos(math.pi * d / halfWidth));
  }

  /// 按样式生成波形(相对基线的纵向偏移,向上为负),
  /// R 尖峰位于 u = 0.5(即心形水平中心)。
  double _ecgWave(EcgStyle style, double u) {
    switch (style) {
      case EcgStyle.none:
      case EcgStyle.flat:
      case EcgStyle.digits:
        return 0;
      case EcgStyle.single:
        // 简化波形:单个高尖峰 + 小回落。
        return _bump(u, 0.5, 0.05, -5.2) + _bump(u, 0.565, 0.04, 1.8);
      case EcgStyle.classic:
        // 完整 P-QRS-T 复合波。
        return _bump(u, 0.30, 0.09, -1.1) // P 波
            + _bump(u, 0.475, 0.028, 0.9) // Q
            + _bump(u, 0.5, 0.045, -5.2) // R 尖峰
            + _bump(u, 0.555, 0.045, 2.6) // S
            + _bump(u, 0.75, 0.13, -2.0); // T 波
    }
  }
}

/// Material Icons favorite 的 24x24 视窗路径(与系统标准 ❤ 同形)。
Path _heartPath() {
  return Path()
    ..moveTo(12, 21.35)
    ..relativeLineTo(-1.45, -1.32)
    ..cubicTo(5.4, 15.36, 2, 12.28, 2, 8.5)
    ..cubicTo(2, 5.42, 4.42, 3, 7.5, 3)
    ..relativeCubicTo(1.74, 0, 3.41, 0.81, 4.5, 2.09)
    ..cubicTo(13.09, 3.81, 14.76, 3, 16.5, 3)
    ..cubicTo(19.58, 3, 22, 5.42, 22, 8.5)
    ..relativeCubicTo(0, 3.78, -3.4, 6.86, -8.55, 11.54)
    ..lineTo(12, 21.35)
    ..close();
}
