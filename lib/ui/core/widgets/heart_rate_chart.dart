import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 近期心率波动折线图(纯 CustomPainter 绘制,无第三方依赖)。
///
/// 绘制内容:水平网格线 → 面积填充 → 深色可读性描边 → 彩色折线 →
/// 末端当前点圆点。Y 轴范围为当前数据 min/max ± 5bpm(跨度不足
/// 20bpm 时自动补足),X 轴铺满可用宽度。
class HeartRateChart extends StatelessWidget {
  /// 创建折线图;[values] 为时间升序的 bpm 采样。
  const HeartRateChart({
    super.key,
    required this.values,
    required this.lineColor,
    this.gridColor = const Color(0x14FFFFFF),
    this.shadowColor = const Color(0x66000000),
    this.areaAlpha = 0.12,
  });

  /// 时间升序的心率采样列表。
  final List<int> values;

  /// 折线与当前点颜色(通常跟随「心电图颜色」)。
  final Color lineColor;

  /// 网格线颜色。
  final Color gridColor;

  /// 折线下方深色可读性描边颜色。
  final Color shadowColor;

  /// 面积填充透明度。
  final double areaAlpha;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _HeartRateChartPainter(
        values: List<int>.of(values),
        lineColor: lineColor,
        gridColor: gridColor,
        shadowColor: shadowColor,
        areaAlpha: areaAlpha,
      ),
    );
  }
}

class _HeartRateChartPainter extends CustomPainter {
  _HeartRateChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
    required this.shadowColor,
    required this.areaAlpha,
  });

  final List<int> values;
  final Color lineColor;
  final Color gridColor;
  final Color shadowColor;
  final double areaAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    // 水平网格线(3 条)。
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) {
      // 数据不足:绘制居中灰色平线占位。
      final baseline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = lineColor.withValues(alpha: 0.3);
      canvas.drawLine(
        Offset(size.width * 0.1, size.height / 2),
        Offset(size.width * 0.9, size.height / 2),
        baseline,
      );
      return;
    }

    // Y 轴动态范围:min/max ± 5bpm,跨度不足 20bpm 自动补足。
    var minY = values.reduce(math.min).toDouble();
    var maxY = values.reduce(math.max).toDouble();
    minY -= 5;
    maxY += 5;
    if (maxY - minY < 20) {
      final mid = (minY + maxY) / 2;
      minY = mid - 10;
      maxY = mid + 10;
    }

    double xOf(int index) =>
        size.width * index / (values.length - 1).clamp(1, values.length);
    double yOf(double bpm) =>
        size.height - (bpm - minY) / (maxY - minY) * size.height;

    // 折线路径。
    final wave = Path();
    var first = true;
    for (var i = 0; i < values.length; i++) {
      final point = Offset(xOf(i), yOf(values[i].toDouble()));
      if (first) {
        wave.moveTo(point.dx, point.dy);
        first = false;
      } else {
        wave.lineTo(point.dx, point.dy);
      }
    }

    // 面积填充(折线 + 底边闭合)。
    final area = Path.from(wave)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = lineColor.withValues(alpha: areaAlpha),
    );

    // 深色可读性描边(浅色背景下仍清晰)。
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = shadowColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 彩色折线。
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = lineColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 末端当前点圆点(白描边突出)。
    final last = Offset(xOf(values.length - 1), yOf(values.last.toDouble()));
    canvas.drawCircle(last, 3.5, Paint()..color = lineColor);
    canvas.drawCircle(
      last,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_HeartRateChartPainter oldDelegate) {
    return values.length != oldDelegate.values.length ||
        (values.isNotEmpty &&
            oldDelegate.values.isNotEmpty &&
            values.last != oldDelegate.values.last) ||
        lineColor != oldDelegate.lineColor ||
        gridColor != oldDelegate.gridColor ||
        shadowColor != oldDelegate.shadowColor ||
        areaAlpha != oldDelegate.areaAlpha;
  }
}
