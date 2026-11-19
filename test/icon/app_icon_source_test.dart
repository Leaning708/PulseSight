import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_sight/ui/core/widgets/heartbeat_heart.dart';

/// 心形视觉重心高于几何中心(两瓣在上、底部收尖),需要整体下移心形
/// 边长的 3.5% 才能看起来居中。桌面图标实测:600 边长下移 21px。
const double _heartOpticalDropRatio = 0.035;

/// 应用图标源图生成器。
///
/// 用应用自身的 [HeartbeatHeart] 绘制器渲染图标源图并写入
/// `assets/icon/`,保证图标与应用内的红心视觉完全一致;源图随后经
/// flutter_launcher_icons(`dart run flutter_launcher_icons`,配置见
/// pubspec.yaml 的 `flutter_launcher_icons` 段)分发到 macOS /
/// Windows / Android 各平台。
///
/// 默认跳过(不影响常规 `flutter test`);需要重新生成图标时执行:
///
/// ```sh
/// flutter test test/icon/app_icon_source_test.dart \
///   --dart-define=PULSESIGHT_GENERATE_APP_ICON=true --update-goldens
/// ```
void main() {
  const generate = bool.fromEnvironment('PULSESIGHT_GENERATE_APP_ICON');

  /// 按 1024×1024 物理像素渲染源图(设备像素比 1.0,保证输出即 1024)。
  Future<void> pumpArtwork(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1024, 1024);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('生成主图标源图 app_icon.png', (tester) async {
    await pumpArtwork(tester, const AppIconArtwork());
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('../../assets/icon/app_icon.png'),
    );
  }, skip: !generate);

  testWidgets('生成 Android 自适应前景图 app_icon_foreground.png', (tester) async {
    await pumpArtwork(tester, const AppIconForeground());
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('../../assets/icon/app_icon_foreground.png'),
    );
  }, skip: !generate);
}

/// 主图标画面:深色圆角卡片 + 红心后方的柔光辉光 +
/// 居中红心(内含完整心电图波形)。
class AppIconArtwork extends StatelessWidget {
  const AppIconArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1024,
      height: 1024,
      child: CustomPaint(
        painter: _IconCardPainter(),
        // 心形整体偏上重(两瓣在上、下尖收尾),光学中心略高于几何中心,
        // 故在几何居中的基础上整体下移(600 × 3.5% ≈ 21px)。
        child: Align(
          alignment: const Alignment(0, 0.1),
          child: HeartbeatHeart(
            size: 600,
            bpm: 72,
            // 相位 0.5:脉冲恰好回到原大(心形静止),心电图整波完整显示。
            pulsePhase: 0.5,
            heartPulseEnabled: false,
          ),
        ),
      ),
    );
  }
}

/// Android 自适应图标前景:透明底 + 居中红心(系统按安全区裁切)。
///
/// 尺寸按「108dp 画布 / 72dp 可见圆区」换算:心形约占自身绘制区的 94%,
/// 取 560 后落在画布约 51%,约为可见圆区直径的 77%,四周留有呼吸感而
/// 不贴边。配合 pubspec 的 `adaptive_icon_foreground_inset: 0`——此前
/// 默认 16% 的额外内缩会把心形压到画布约 35%,看起来"黑边过大"。
class AppIconForeground extends StatelessWidget {
  const AppIconForeground({super.key});

  /// 心形绘制区边长(1024 画布内)。
  static const double heartSize = 560;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1024,
      height: 1024,
      child: Center(
        // 与桌面图标一致的光学居中:整体下移心形边长的 3.5%。
        child: Transform.translate(
          offset: const Offset(0, heartSize * _heartOpticalDropRatio),
          child: const HeartbeatHeart(
            size: heartSize,
            bpm: 72,
            pulsePhase: 0.5,
            heartPulseEnabled: false,
          ),
        ),
      ),
    );
  }
}

/// 图标卡片绘制:深色渐变底、心形辉光与淡高光描边。
class _IconCardPainter extends CustomPainter {
  /// 卡片相对画布的内边距(四边留 84 透明区,符合 macOS 图标网格)。
  static const double _cardInset = 84;

  /// 卡片圆角。
  static const double _cardRadius = 192;

  /// 辉光与红心的垂直偏移:与 [AppIconArtwork] 的 Alignment.y 0.1
  /// 保持一致((1024 - 600) / 2 * 0.1 ≈ 21px)。
  static const double _heartDrop = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_cardInset),
      const Radius.circular(_cardRadius),
    );

    // 卡片底:深色渐变,明度略高于舞台色以保留层次。
    canvas.drawRRect(
      card,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2026), Color(0xFF131418)],
        ).createShader(card.outerRect),
    );

    // 红心后方的柔光辉光,呼应应用内的心跳辉光。
    const glowRadius = 380.0;
    final glowCenter = card.outerRect.center + const Offset(0, _heartDrop);
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x4DE23A3A), Color(0x00E23A3A)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowRadius)),
    );

    // 内描边:极淡高光勾边,深色 Dock 背景下仍能看清轮廓。
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x14FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_IconCardPainter oldDelegate) => false;
}
