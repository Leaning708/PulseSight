import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// 心率数字相对心形的位置。
enum BpmPosition {
  /// 数字在心形上方。
  top,

  /// 数字在心形下方。
  bottom,

  /// 数字在心形左侧。
  left,

  /// 数字在心形右侧。
  right,

  /// 不显示数字。
  hidden;

  /// 从持久化的字符串还原;无法识别时回退为 [BpmPosition.bottom]。
  static BpmPosition fromString(String? value) => BpmPosition.values.firstWhere(
    (v) => v.name == value,
    orElse: () => BpmPosition.bottom,
  );
}

/// 心形内部心电图线的样式。
enum EcgStyle {
  /// 不显示心电图。
  none,

  /// 平直基线。
  flat,

  /// 单尖峰(简化波形)。
  single,

  /// 完整 P-QRS-T 经典心电波形。
  classic,

  /// 心形内部直接显示 BPM 数字(替代波形)。
  digits;

  /// 从持久化的字符串还原;无法识别时回退为 [EcgStyle.classic]。
  static EcgStyle fromString(String? value) => EcgStyle.values.firstWhere(
    (v) => v.name == value,
    orElse: () => EcgStyle.classic,
  );
}

/// 悬浮窗显示样式:心形大小、数字大小与位置、心电图样式、间距。
///
/// 由主界面调节并持久化,经平台通道推送到各悬浮窗引擎。
@immutable
class OverlayStyle {
  /// 创建样式配置;各参数均有默认值。
  const OverlayStyle({
    this.heartSize = 64,
    this.bpmFontSize = 20,
    this.bpmPosition = BpmPosition.bottom,
    this.ecgStyle = EcgStyle.classic,
    this.gap = 6,
    this.opacity = 1.0,
    this.backgroundOpacity = 0.0,
    this.backgroundColor = defaultBackgroundColor,
    this.backgroundWidth = 130,
    this.backgroundHeight = 170,
    this.textColor = defaultTextColor,
    this.heartColor = defaultHeartColor,
    this.ecgColor = defaultEcgColor,
    this.showBpmLabel = true,
    this.textWeight = 700,
    this.textFontFamily,
    this.showChart = false,
    this.chartSeconds = 30,
    this.chartLineColor = defaultChartLineColor,
    this.chartHeight = 84,
    this.chartSpacing = 8,
    this.heartPulseEnabled = true,
    this.textPulseEnabled = true,
    this.glowRadius = 1.0,
    this.glowOpacity = 0.5,
  });

  /// 心形绘制边长(逻辑像素)。
  final double heartSize;

  /// 心率数字字号(逻辑像素)。
  final double bpmFontSize;

  /// 心率数字位置。
  final BpmPosition bpmPosition;

  /// 心电图样式。
  final EcgStyle ecgStyle;

  /// 心形与数字之间的间距(逻辑像素)。
  final double gap;

  /// 心率内容(心形 + 数字)不透明度(0.1 ~ 1.0)。
  final double opacity;

  /// 背景板(内容底部的深色底板)不透明度(0.0 = 无背景板,1.0 = 不透明)。
  final double backgroundOpacity;

  /// 背景板颜色(配合 backgroundOpacity 使用)。
  final Color backgroundColor;

  /// 背景板宽度(逻辑像素)。
  final double backgroundWidth;

  /// 背景板高度(逻辑像素)。
  final double backgroundHeight;

  /// 心率数字文字颜色。
  final Color textColor;

  /// 心形颜色。
  final Color heartColor;

  /// 心电图线颜色(digits 样式的心内数字同色)。
  final Color ecgColor;

  /// 心形是否随心跳脉冲缩放(关闭后心形静止,心电图动画照常)。
  final bool heartPulseEnabled;

  /// 心率数字是否随心跳同步律动(关闭后数字静止)。
  final bool textPulseEnabled;

  /// 心跳辉光强度(0 = 无辉光,1.0 = 默认,最大 3.0)。
  /// 辉光半径倍率(0 ~ 3.0)。
  final double glowRadius;

  /// 辉光透明度倍率(0.0 ~ 1.0)。
  final double glowOpacity;

  /// 是否显示 “bpm” 标签。
  final bool showBpmLabel;

  /// 数字字重(100 ~ 900,映射 FontWeight)。
  final double textWeight;

  /// 数字字体族;null = 跟随全局字体设置(全局未设置时为系统默认)。
  final String? textFontFamily;

  /// 是否显示近期心率波动折线图。
  final bool showChart;

  /// 折线图采集时长(秒,10 ~ 120)。
  final double chartSeconds;

  /// 折线图颜色(默认与心形同色系的心率红)。
  final Color chartLineColor;

  /// 折线图高度(逻辑像素,40 ~ 160)。
  final double chartHeight;

  /// 折线图与心形/数字内容的间距(逻辑像素,0 ~ 24)。
  final double chartSpacing;

  /// 按采集时长折算的历史采样点数上限(按 0.8s 采样间隔估算)。
  int get chartSampleCount =>
      ((chartSeconds * 1000) / 800).round().clamp(2, 1000);

  /// 背景板默认颜色(深灰)。
  static const Color defaultBackgroundColor = Color(0xFF17181C);

  /// 文字默认颜色(白)。
  static const Color defaultTextColor = Color(0xFFFFFFFF);

  /// 心形默认颜色(心率红)。
  static const Color defaultHeartColor = Color(0xFFE23A3A);

  /// 心电图线默认颜色(白)。
  static const Color defaultEcgColor = Color(0xFFFFFFFF);

  /// 折线图默认颜色(与心形默认同色系的心率红)。
  static const Color defaultChartLineColor = Color(0xFFE23A3A);

  /// 默认样式。
  static const OverlayStyle defaults = OverlayStyle();

  /// 复制并替换部分字段。
  ///
  /// [textFontFamily] 传 null 时保留原值(与其他可空字段一致);需要
  /// 显式清空回「跟随全局字体」时传 [clearTextFontFamily] 为 true。
  OverlayStyle copyWith({
    double? heartSize,
    double? bpmFontSize,
    BpmPosition? bpmPosition,
    EcgStyle? ecgStyle,
    double? gap,
    double? opacity,
    double? backgroundOpacity,
    Color? backgroundColor,
    double? backgroundWidth,
    double? backgroundHeight,
    Color? textColor,
    Color? heartColor,
    Color? ecgColor,
    bool? showBpmLabel,
    double? textWeight,
    String? textFontFamily,
    bool clearTextFontFamily = false,
    bool? showChart,
    double? chartSeconds,
    Color? chartLineColor,
    double? chartHeight,
    double? chartSpacing,
    bool? heartPulseEnabled,
    bool? textPulseEnabled,
    double? glowRadius,
    double? glowOpacity,
  }) {
    return OverlayStyle(
      heartSize: heartSize ?? this.heartSize,
      bpmFontSize: bpmFontSize ?? this.bpmFontSize,
      bpmPosition: bpmPosition ?? this.bpmPosition,
      ecgStyle: ecgStyle ?? this.ecgStyle,
      gap: gap ?? this.gap,
      opacity: opacity ?? this.opacity,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundWidth: backgroundWidth ?? this.backgroundWidth,
      backgroundHeight: backgroundHeight ?? this.backgroundHeight,
      textColor: textColor ?? this.textColor,
      heartColor: heartColor ?? this.heartColor,
      ecgColor: ecgColor ?? this.ecgColor,
      showBpmLabel: showBpmLabel ?? this.showBpmLabel,
      textWeight: textWeight ?? this.textWeight,
      textFontFamily: clearTextFontFamily
          ? null
          : (textFontFamily ?? this.textFontFamily),
      showChart: showChart ?? this.showChart,
      chartSeconds: chartSeconds ?? this.chartSeconds,
      chartLineColor: chartLineColor ?? this.chartLineColor,
      chartHeight: chartHeight ?? this.chartHeight,
      chartSpacing: chartSpacing ?? this.chartSpacing,
      heartPulseEnabled: heartPulseEnabled ?? this.heartPulseEnabled,
      textPulseEnabled: textPulseEnabled ?? this.textPulseEnabled,
      glowRadius: glowRadius ?? this.glowRadius,
      glowOpacity: glowOpacity ?? this.glowOpacity,
    );
  }

  /// 序列化为可经平台通道传递的映射。
  Map<String, Object?> toJson() => {
    'heartSize': heartSize,
    'bpmFontSize': bpmFontSize,
    'bpmPosition': bpmPosition.name,
    'ecgStyle': ecgStyle.name,
    'gap': gap,
    'opacity': opacity,
    'backgroundOpacity': backgroundOpacity,
    'backgroundColor': backgroundColor.toARGB32(),
    'backgroundWidth': backgroundWidth,
    'backgroundHeight': backgroundHeight,
    'textColor': textColor.toARGB32(),
    'heartColor': heartColor.toARGB32(),
    'ecgColor': ecgColor.toARGB32(),
    'showBpmLabel': showBpmLabel,
    'textWeight': textWeight,
    'textFontFamily': textFontFamily,
    'showChart': showChart,
    'chartSeconds': chartSeconds,
    'chartLineColor': chartLineColor.toARGB32(),
    'chartHeight': chartHeight,
    'chartSpacing': chartSpacing,
    'heartPulseEnabled': heartPulseEnabled,
    'textPulseEnabled': textPulseEnabled,
    'glowRadius': glowRadius,
    'glowOpacity': glowOpacity,
  };

  /// 从平台通道传来的映射还原;缺失或非法字段回退为默认值。
  factory OverlayStyle.fromJson(Map<dynamic, dynamic> json) {
    Color colorFromJson(Object? value, Color fallback) =>
        value is int ? Color(value) : fallback;

    return OverlayStyle(
      heartSize: json['heartSize'] is num
          ? (json['heartSize'] as num).toDouble()
          : 64,
      bpmFontSize: json['bpmFontSize'] is num
          ? (json['bpmFontSize'] as num).toDouble()
          : 20,
      bpmPosition: BpmPosition.fromString(json['bpmPosition'] as String?),
      ecgStyle: EcgStyle.fromString(json['ecgStyle'] as String?),
      gap: json['gap'] is num ? (json['gap'] as num).toDouble() : 6,
      opacity: json['opacity'] is num
          ? (json['opacity'] as num).toDouble().clamp(0.1, 1.0)
          : 1.0,
      backgroundOpacity: json['backgroundOpacity'] is num
          ? (json['backgroundOpacity'] as num).toDouble().clamp(0.0, 1.0)
          : 0.0,
      backgroundColor: colorFromJson(
        json['backgroundColor'],
        defaultBackgroundColor,
      ),
      backgroundWidth: json['backgroundWidth'] is num
          ? (json['backgroundWidth'] as num).toDouble()
          : 130,
      backgroundHeight: json['backgroundHeight'] is num
          ? (json['backgroundHeight'] as num).toDouble()
          : 170,
      textColor: colorFromJson(json['textColor'], defaultTextColor),
      heartColor: colorFromJson(json['heartColor'], defaultHeartColor),
      ecgColor: colorFromJson(json['ecgColor'], defaultEcgColor),
      showBpmLabel: json['showBpmLabel'] is bool
          ? json['showBpmLabel'] as bool
          : true,
      textWeight: json['textWeight'] is num
          ? (json['textWeight'] as num).toDouble().clamp(100.0, 900.0)
          : 700,
      textFontFamily: json['textFontFamily'] is String
          ? json['textFontFamily'] as String
          : null,
      showChart: json['showChart'] is bool ? json['showChart'] as bool : false,
      chartSeconds: json['chartSeconds'] is num
          ? (json['chartSeconds'] as num).toDouble().clamp(10.0, 120.0)
          : 30,
      chartLineColor: colorFromJson(
        json['chartLineColor'],
        defaultChartLineColor,
      ),
      chartHeight: json['chartHeight'] is num
          ? (json['chartHeight'] as num).toDouble().clamp(40.0, 160.0)
          : 84,
      chartSpacing: json['chartSpacing'] is num
          ? (json['chartSpacing'] as num).toDouble().clamp(0.0, 24.0)
          : 8,
      heartPulseEnabled: json['heartPulseEnabled'] is bool
          ? json['heartPulseEnabled'] as bool
          : true,
      textPulseEnabled: json['textPulseEnabled'] is bool
          ? json['textPulseEnabled'] as bool
          : true,
      glowRadius: json['glowRadius'] is num
          ? (json['glowRadius'] as num).toDouble().clamp(0.0, 3.0)
          : 1.0,
      glowOpacity: json['glowOpacity'] is num
          ? (json['glowOpacity'] as num).toDouble().clamp(0.0, 1.0)
          : 0.5,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OverlayStyle &&
      other.heartSize == heartSize &&
      other.bpmFontSize == bpmFontSize &&
      other.bpmPosition == bpmPosition &&
      other.ecgStyle == ecgStyle &&
      other.gap == gap &&
      other.opacity == opacity &&
      other.backgroundOpacity == backgroundOpacity &&
      other.backgroundColor == backgroundColor &&
      other.backgroundWidth == backgroundWidth &&
      other.backgroundHeight == backgroundHeight &&
      other.textColor == textColor &&
      other.heartColor == heartColor &&
      other.ecgColor == ecgColor &&
      other.showBpmLabel == showBpmLabel &&
      other.textWeight == textWeight &&
      other.textFontFamily == textFontFamily &&
      other.showChart == showChart &&
      other.chartSeconds == chartSeconds &&
      other.chartLineColor == chartLineColor &&
      other.chartHeight == chartHeight &&
      other.chartSpacing == chartSpacing &&
      other.heartPulseEnabled == heartPulseEnabled &&
      other.textPulseEnabled == textPulseEnabled &&
      other.glowRadius == glowRadius &&
      other.glowOpacity == glowOpacity;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    heartSize,
    bpmFontSize,
    bpmPosition,
    ecgStyle,
    gap,
    opacity,
    backgroundOpacity,
    backgroundColor,
    backgroundWidth,
    backgroundHeight,
    textColor,
    heartColor,
    ecgColor,
    showBpmLabel,
    textWeight,
    textFontFamily,
    showChart,
    chartSeconds,
    chartLineColor,
    chartHeight,
    chartSpacing,
    heartPulseEnabled,
    textPulseEnabled,
    glowRadius,
    glowOpacity,
  ]);
}
