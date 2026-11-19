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
    this.heartTextGap = 6,
    this.contentOpacity = 1.0,
    this.backgroundOpacity = 0.0,
    this.backgroundColor = defaultBackgroundColor,
    this.backgroundWidth = defaultBackgroundWidth,
    this.backgroundHeight = defaultBackgroundHeight,
    this.bpmColor = defaultTextColor,
    this.heartColor = defaultHeartColor,
    this.ecgColor = defaultEcgColor,
    this.showBpmLabel = true,
    this.bpmWeight = 700,
    this.bpmFontFamily,
    this.showChart = false,
    this.chartSeconds = 30,
    this.chartLineColor = defaultChartLineColor,
    this.chartHeight = 84,
    this.chartSpacing = 8,
    this.heartPulseEnabled = true,
    this.bpmPulseEnabled = true,
    this.glowEnabled = true,
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
  final double heartTextGap;

  /// 心率内容(心形 + 数字)整体不透明度(0.1 ~ 1.0)。
  final double contentOpacity;

  /// 背景板(内容底部的深色底板)不透明度(0.0 = 无背景板,1.0 = 不透明)。
  final double backgroundOpacity;

  /// 背景板颜色(配合 backgroundOpacity 使用)。
  final Color backgroundColor;

  /// 背景板宽度(逻辑像素)。
  final double backgroundWidth;

  /// 背景板高度(逻辑像素)。
  final double backgroundHeight;

  /// 心率数字颜色。
  final Color bpmColor;

  /// 心形颜色。
  final Color heartColor;

  /// 心电图线颜色(digits 样式的心内数字同色)。
  final Color ecgColor;

  /// 心形是否随心跳脉冲缩放(关闭后心形静止,心电图动画照常)。
  final bool heartPulseEnabled;

  /// 心率数字是否随心跳同步律动(关闭后数字静止)。
  final bool bpmPulseEnabled;

  /// 是否启用心跳辉光(关闭后不再绘制外扩光晕,半径/透明度设置保留)。
  final bool glowEnabled;

  /// 辉光半径倍率(0 = 无辉光,1.0 = 默认,最大 3.0)。
  final double glowRadius;

  /// 辉光透明度倍率(0.0 ~ 1.0)。
  final double glowOpacity;

  /// 是否显示 “bpm” 标签。
  final bool showBpmLabel;

  /// 数字字重(100 ~ 900,映射 FontWeight)。
  final double bpmWeight;

  /// 数字字体族;null = 跟随全局字体设置(全局未设置时为系统默认)。
  final String? bpmFontFamily;

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

  /// 背景板默认宽度(逻辑像素);Android 悬浮窗初始尺寸同源取此值。
  static const double defaultBackgroundWidth = 130;

  /// 背景板默认高度(逻辑像素)。
  static const double defaultBackgroundHeight = 170;

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
  /// [bpmFontFamily] 传 null 时保留原值(与其他可空字段一致);需要
  /// 显式清空回「跟随全局字体」时传 [clearBpmFontFamily] 为 true。
  OverlayStyle copyWith({
    double? heartSize,
    double? bpmFontSize,
    BpmPosition? bpmPosition,
    EcgStyle? ecgStyle,
    double? heartTextGap,
    double? contentOpacity,
    double? backgroundOpacity,
    Color? backgroundColor,
    double? backgroundWidth,
    double? backgroundHeight,
    Color? bpmColor,
    Color? heartColor,
    Color? ecgColor,
    bool? showBpmLabel,
    double? bpmWeight,
    String? bpmFontFamily,
    bool clearBpmFontFamily = false,
    bool? showChart,
    double? chartSeconds,
    Color? chartLineColor,
    double? chartHeight,
    double? chartSpacing,
    bool? heartPulseEnabled,
    bool? bpmPulseEnabled,
    bool? glowEnabled,
    double? glowRadius,
    double? glowOpacity,
  }) {
    return OverlayStyle(
      heartSize: heartSize ?? this.heartSize,
      bpmFontSize: bpmFontSize ?? this.bpmFontSize,
      bpmPosition: bpmPosition ?? this.bpmPosition,
      ecgStyle: ecgStyle ?? this.ecgStyle,
      heartTextGap: heartTextGap ?? this.heartTextGap,
      contentOpacity: contentOpacity ?? this.contentOpacity,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundWidth: backgroundWidth ?? this.backgroundWidth,
      backgroundHeight: backgroundHeight ?? this.backgroundHeight,
      bpmColor: bpmColor ?? this.bpmColor,
      heartColor: heartColor ?? this.heartColor,
      ecgColor: ecgColor ?? this.ecgColor,
      showBpmLabel: showBpmLabel ?? this.showBpmLabel,
      bpmWeight: bpmWeight ?? this.bpmWeight,
      bpmFontFamily: clearBpmFontFamily
          ? null
          : (bpmFontFamily ?? this.bpmFontFamily),
      showChart: showChart ?? this.showChart,
      chartSeconds: chartSeconds ?? this.chartSeconds,
      chartLineColor: chartLineColor ?? this.chartLineColor,
      chartHeight: chartHeight ?? this.chartHeight,
      chartSpacing: chartSpacing ?? this.chartSpacing,
      heartPulseEnabled: heartPulseEnabled ?? this.heartPulseEnabled,
      bpmPulseEnabled: bpmPulseEnabled ?? this.bpmPulseEnabled,
      glowEnabled: glowEnabled ?? this.glowEnabled,
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
    'heartTextGap': heartTextGap,
    'contentOpacity': contentOpacity,
    'backgroundOpacity': backgroundOpacity,
    'backgroundColor': backgroundColor.toARGB32(),
    'backgroundWidth': backgroundWidth,
    'backgroundHeight': backgroundHeight,
    'bpmColor': bpmColor.toARGB32(),
    'heartColor': heartColor.toARGB32(),
    'ecgColor': ecgColor.toARGB32(),
    'showBpmLabel': showBpmLabel,
    'bpmWeight': bpmWeight,
    'bpmFontFamily': bpmFontFamily,
    'showChart': showChart,
    'chartSeconds': chartSeconds,
    'chartLineColor': chartLineColor.toARGB32(),
    'chartHeight': chartHeight,
    'chartSpacing': chartSpacing,
    'heartPulseEnabled': heartPulseEnabled,
    'bpmPulseEnabled': bpmPulseEnabled,
    'glowEnabled': glowEnabled,
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
      heartTextGap: json['heartTextGap'] is num
          ? (json['heartTextGap'] as num).toDouble()
          : 6,
      contentOpacity: json['contentOpacity'] is num
          ? (json['contentOpacity'] as num).toDouble().clamp(0.1, 1.0)
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
          : defaultBackgroundWidth,
      backgroundHeight: json['backgroundHeight'] is num
          ? (json['backgroundHeight'] as num).toDouble()
          : defaultBackgroundHeight,
      bpmColor: colorFromJson(json['bpmColor'], defaultTextColor),
      heartColor: colorFromJson(json['heartColor'], defaultHeartColor),
      ecgColor: colorFromJson(json['ecgColor'], defaultEcgColor),
      showBpmLabel: json['showBpmLabel'] is bool
          ? json['showBpmLabel'] as bool
          : true,
      bpmWeight: json['bpmWeight'] is num
          ? (json['bpmWeight'] as num).toDouble().clamp(100.0, 900.0)
          : 700,
      bpmFontFamily: json['bpmFontFamily'] is String
          ? json['bpmFontFamily'] as String
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
      bpmPulseEnabled: json['bpmPulseEnabled'] is bool
          ? json['bpmPulseEnabled'] as bool
          : true,
      glowEnabled: json['glowEnabled'] is bool
          ? json['glowEnabled'] as bool
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
      other.heartTextGap == heartTextGap &&
      other.contentOpacity == contentOpacity &&
      other.backgroundOpacity == backgroundOpacity &&
      other.backgroundColor == backgroundColor &&
      other.backgroundWidth == backgroundWidth &&
      other.backgroundHeight == backgroundHeight &&
      other.bpmColor == bpmColor &&
      other.heartColor == heartColor &&
      other.ecgColor == ecgColor &&
      other.showBpmLabel == showBpmLabel &&
      other.bpmWeight == bpmWeight &&
      other.bpmFontFamily == bpmFontFamily &&
      other.showChart == showChart &&
      other.chartSeconds == chartSeconds &&
      other.chartLineColor == chartLineColor &&
      other.chartHeight == chartHeight &&
      other.chartSpacing == chartSpacing &&
      other.heartPulseEnabled == heartPulseEnabled &&
      other.bpmPulseEnabled == bpmPulseEnabled &&
      other.glowEnabled == glowEnabled &&
      other.glowRadius == glowRadius &&
      other.glowOpacity == glowOpacity;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    heartSize,
    bpmFontSize,
    bpmPosition,
    ecgStyle,
    heartTextGap,
    contentOpacity,
    backgroundOpacity,
    backgroundColor,
    backgroundWidth,
    backgroundHeight,
    bpmColor,
    heartColor,
    ecgColor,
    showBpmLabel,
    bpmWeight,
    bpmFontFamily,
    showChart,
    chartSeconds,
    chartLineColor,
    chartHeight,
    chartSpacing,
    heartPulseEnabled,
    bpmPulseEnabled,
    glowEnabled,
    glowRadius,
    glowOpacity,
  ]);
}
