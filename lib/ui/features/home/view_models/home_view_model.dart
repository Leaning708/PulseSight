import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/platform/android_display_service.dart';
import '../../../../data/services/platform/desktop_overlay_service.dart';
import '../../../../data/services/platform/font_list_service.dart';
import '../../../../data/services/platform/macos_menubar_service.dart';
import '../../../../data/repositories/heart_rate_repository.dart';
import '../../../../domain/models/heart_rate_connection.dart';
import '../../../../domain/models/heart_rate_reading.dart';
import '../../../../domain/models/heart_rate_history.dart';
import '../../../../domain/models/overlay_style.dart';

/// 主界面 ViewModel:连接管理与各显示端开关。
///
/// 平台不支持的显示端服务以 null 注入,对应开关由
/// [supportsDesktopOverlay] 等能力位控制不渲染。
class HomeViewModel extends ChangeNotifier {
  /// 创建 ViewModel;平台不支持的显示端服务传 null。
  HomeViewModel({
    required this._repository,
    required this._settings,
    this._desktopOverlay,
    this._menubar,
    this._androidDisplay,
  });

  final HeartRateRepository _repository;
  final SettingsRepository _settings;
  final DesktopOverlay? _desktopOverlay;
  final MenubarDisplay? _menubar;
  final AndroidDisplay? _androidDisplay;
  final FontListService _fontList = FontListService();

  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;

  bool _initialized = false;

  HeartRateConnection _connection = HeartRateConnection.disconnected;

  int? _bpm;

  bool _desktopOverlayEnabled = false;

  bool _mousePassthroughEnabled = false;

  bool _menubarEnabled = false;

  bool _androidOverlayEnabled = false;

  bool _statusBarEnabled = false;

  OverlayStyle _overlayStyle = OverlayStyle.defaults;

  /// 近期心率采样历史(供主界面预览折线图使用)。
  final HeartRateHistory _heartRateHistory = HeartRateHistory();

  /// 近期心率采样历史(只读)。
  HeartRateHistory get heartRateHistory => _heartRateHistory;

  /// 是否支持桌面悬浮窗(Windows / macOS)。
  bool get supportsDesktopOverlay => _desktopOverlay != null;

  /// 是否支持 macOS 菜单栏显示。
  bool get supportsMenubar => _menubar != null;

  /// 是否支持 Android 显示端(悬浮窗 / 状态栏)。
  bool get supportsAndroidDisplay => _androidDisplay != null;

  /// 当前连接状态。
  HeartRateConnection get connection => _connection;

  /// 最近一次心率。
  int? get bpm => _bpm;

  /// 桌面悬浮窗开关状态。
  bool get desktopOverlayEnabled => _desktopOverlayEnabled;

  /// 鼠标穿透开关状态(仅悬浮窗开启时有效)。
  bool get mousePassthroughEnabled => _mousePassthroughEnabled;

  /// macOS 菜单栏显示开关状态。
  bool get menubarEnabled => _menubarEnabled;

  /// Android 悬浮窗开关状态。
  bool get androidOverlayEnabled => _androidOverlayEnabled;

  /// Android 状态栏通知开关状态。
  bool get statusBarEnabled => _statusBarEnabled;

  /// 悬浮窗显示样式。
  OverlayStyle get overlayStyle => _overlayStyle;

  /// 系统已安装字体族列表(懒加载)。
  List<String> get overlayFontFamilies => _fontList.fontFamilies;

  /// 是否可以发起连接(未连接时)。
  bool get canConnect => _connection == HeartRateConnection.disconnected;

  /// 初始化:订阅数据流、加载持久化设置并恢复桌面显示端。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 字体列表懒加载,完成后通知 UI 刷新字体下拉。
    unawaited(_fontList.load().then((_) => notifyListeners()));

    _connection = _repository.status;
    _bpm = _repository.currentBpm;
    _readingsSub = _repository.readings.listen((reading) {
      _bpm = reading.bpm;
      _heartRateHistory.add(reading.bpm);
      notifyListeners();
    });
    _connectionSub = _repository.connection.listen((status) {
      _connection = status;
      if (status != HeartRateConnection.connected) {
        _heartRateHistory.clear();
      }
      notifyListeners();
    });

    final values = await _settings.loadAll();
    _desktopOverlayEnabled =
        (values[SettingsKeys.desktopOverlayEnabled] as bool?) ?? false;
    _mousePassthroughEnabled =
        (values[SettingsKeys.mousePassthroughEnabled] as bool?) ?? false;
    // 菜单栏心率默认显示(用户关闭过则以持久化值为准)。
    _menubarEnabled = (values[SettingsKeys.menubarEnabled] as bool?) ?? true;
    _androidOverlayEnabled =
        (values[SettingsKeys.androidOverlayEnabled] as bool?) ?? false;
    _statusBarEnabled = (values[SettingsKeys.statusBarEnabled] as bool?) ?? false;
    _overlayStyle = OverlayStyle(
      heartSize: (values[SettingsKeys.overlayHeartSize] as double?) ?? 64,
      bpmFontSize: (values[SettingsKeys.overlayBpmFontSize] as double?) ?? 20,
      bpmPosition: BpmPosition.fromString(
          values[SettingsKeys.overlayBpmPosition] as String?),
      ecgStyle: EcgStyle.fromString(
          values[SettingsKeys.overlayEcgStyle] as String?),
      gap: (values[SettingsKeys.overlayGap] as double?) ?? 6,
      opacity: (values[SettingsKeys.overlayOpacity] as double?) ?? 1.0,
      backgroundOpacity:
          (values[SettingsKeys.overlayBackgroundOpacity] as double?) ?? 0.0,
      backgroundColor: _colorFromHex(values[SettingsKeys.overlayBackgroundColor] as String?,
          OverlayStyle.defaultBackgroundColor),
      backgroundWidth:
          (values[SettingsKeys.overlayBackgroundWidth] as double?) ?? 130,
      backgroundHeight:
          (values[SettingsKeys.overlayBackgroundHeight] as double?) ?? 170,
      textColor: _colorFromHex(values[SettingsKeys.overlayTextColor] as String?,
          OverlayStyle.defaultTextColor),
      heartColor: _colorFromHex(values[SettingsKeys.overlayHeartColor] as String?,
          OverlayStyle.defaultHeartColor),
      ecgColor: _colorFromHex(values[SettingsKeys.overlayEcgColor] as String?,
          OverlayStyle.defaultEcgColor),
      showChart: (values[SettingsKeys.overlayShowChart] as bool?) ?? false,
      chartSeconds: (values[SettingsKeys.overlayChartSeconds] as double?) ?? 30,
      chartLineColor: _colorFromHex(values[SettingsKeys.overlayChartLineColor] as String?,
          OverlayStyle.defaultChartLineColor),
      chartHeight:
          (values[SettingsKeys.overlayChartHeight] as double?) ?? 84,
      chartSpacing:
          (values[SettingsKeys.overlayChartSpacing] as double?) ?? 8,
      showBpmLabel: (values[SettingsKeys.overlayShowBpmLabel] as bool?) ?? true,
      textWeight: (values[SettingsKeys.overlayTextWeight] as double?) ?? 700,
      textFontFamily:
          values[SettingsKeys.overlayTextFontFamily] as String?,
      heartPulseEnabled:
          (values[SettingsKeys.overlayHeartPulseEnabled] as bool?) ?? true,
      textPulseEnabled:
          (values[SettingsKeys.overlayTextPulseEnabled] as bool?) ?? true,
      glowRadius: (values[SettingsKeys.overlayGlowRadius] as double?)
              ?.clamp(0.0, 3.0) ??
          1.0,
      glowOpacity: (values[SettingsKeys.overlayGlowOpacity] as double?)
              ?.clamp(0.0, 1.0) ??
          0.5,
    );
    notifyListeners();

    // 恢复上次会话开启的显示端(Android 悬浮窗需手动开启)。
    if (_desktopOverlayEnabled) {
      await _desktopOverlay?.show(passthrough: _mousePassthroughEnabled);
      await _desktopOverlay?.setStyle(_overlayStyle);
    }
    if (_menubarEnabled) {
      await _menubar?.setEnabled(true);
    }
    if (_statusBarEnabled) {
      await _androidDisplay?.setStatusBarEnabled(true);
    }
    await _androidDisplay?.setStyle(_overlayStyle);
    _heartRateHistory.maxLength = _overlayStyle.chartSampleCount;
  }

  /// 连接手环(模拟)。
  Future<void> connect() async {
    await _repository.connect();
  }

  /// 断开手环。
  Future<void> disconnect() async {
    await _repository.disconnect();
  }

  /// 开关桌面悬浮窗。
  Future<void> setDesktopOverlayEnabled(bool value) async {
    if (_desktopOverlayEnabled == value) return;
    _desktopOverlayEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.desktopOverlayEnabled, value);
    if (value) {
      await _desktopOverlay?.show(passthrough: _mousePassthroughEnabled);
    } else {
      await _desktopOverlay?.hide();
    }
  }

  /// 开关鼠标穿透。
  Future<void> setMousePassthroughEnabled(bool value) async {
    if (_mousePassthroughEnabled == value) return;
    _mousePassthroughEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.mousePassthroughEnabled, value);
    await _desktopOverlay?.setPassthrough(value);
  }

  /// 开关 macOS 菜单栏心率显示。
  Future<void> setMenubarEnabled(bool value) async {
    if (_menubarEnabled == value) return;
    _menubarEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.menubarEnabled, value);
    await _menubar?.setEnabled(value);
  }

  /// 开关 Android 悬浮窗;权限未授予时返回 false 并不改变开关状态。
  Future<bool> setAndroidOverlayEnabled(bool value) async {
    if (_androidOverlayEnabled == value) return true;
    if (value) {
      final granted = await _androidDisplay?.ensureOverlayPermission() ?? false;
      if (!granted) return false;
      await _androidDisplay?.showOverlay();
    } else {
      await _androidDisplay?.hideOverlay();
    }
    _androidOverlayEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.androidOverlayEnabled, value);
    return true;
  }

  /// 开关状态栏心率通知;通知权限未授予时返回 false 并不改变开关状态。
  Future<bool> setStatusBarEnabled(bool value) async {
    if (_statusBarEnabled == value) return true;
    final ok = await _androidDisplay?.setStatusBarEnabled(value) ?? false;
    if (!ok) return false;
    _statusBarEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.statusBarEnabled, value);
    return true;
  }

  /// 更新心形大小(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayHeartSize(double value) {
    _applyOverlayStyle(_overlayStyle.copyWith(heartSize: value.clamp(36.0, 96.0)));
  }

  /// 更新心率数字字号。
  void setOverlayBpmFontSize(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(bpmFontSize: value.clamp(12.0, 36.0)));
  }

  /// 更新心形与数字的间距。
  void setOverlayGap(double value) {
    _applyOverlayStyle(_overlayStyle.copyWith(gap: value.clamp(0.0, 24.0)));
  }

  /// 更新悬浮窗心率内容(心形 + 数字)不透明度。
  void setOverlayOpacity(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(opacity: value.clamp(0.1, 1.0)));
  }

  /// 更新悬浮窗背景板不透明度(0 = 无背景板)。
  void setOverlayBackgroundOpacity(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(backgroundOpacity: value.clamp(0.0, 1.0)));
  }

  /// 更新悬浮窗背景板颜色并持久化。
  void setOverlayBackgroundColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(backgroundColor: color));
    persistOverlayStyle();
  }

  /// 更新文字颜色并持久化。
  void setOverlayTextColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(textColor: color));
    persistOverlayStyle();
  }

  /// 更新心形颜色并持久化。
  void setOverlayHeartColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(heartColor: color));
    persistOverlayStyle();
  }

  /// 更新心电图颜色并持久化。
  void setOverlayEcgColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(ecgColor: color));
    persistOverlayStyle();
  }

  /// 更新背景板宽度(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayBackgroundWidth(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(backgroundWidth: value.clamp(100.0, 240.0)));
  }

  /// 更新背景板高度(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayBackgroundHeight(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(backgroundHeight: value.clamp(120.0, 280.0)));
  }

  /// 更新是否显示 “bpm” 标签并持久化。
  void setOverlayShowBpmLabel(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(showBpmLabel: value));
    persistOverlayStyle();
  }

  /// 更新数字字重并持久化。
  void setOverlayTextWeight(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(textWeight: value.clamp(100.0, 900.0)));
    persistOverlayStyle();
  }

  /// 更新数字字体族并持久化;null 表示系统默认。
  void setOverlayTextFontFamily(String? family) {
    _applyOverlayStyle(_overlayStyle.copyWith(textFontFamily: family));
    persistOverlayStyle();
  }

  /// 开关心率折线图并持久化;开启时背景板过小会自动放大。
  void setOverlayShowChart(bool value) {
    var style = _overlayStyle.copyWith(showChart: value);
    if (value) {
      // 折线图需要额外高度与宽度,背景板过小时自动放大(仅一次,可再手动调整)。
      style = style.copyWith(
        backgroundWidth: style.backgroundWidth < 180 ? 180 : style.backgroundWidth,
        backgroundHeight: style.backgroundHeight < 240 ? 240 : style.backgroundHeight,
      );
    }
    _applyOverlayStyle(style);
    persistOverlayStyle();
  }

  /// 更新折线图采集时长并持久化(同步历史缓冲长度)。
  void setOverlayChartSeconds(double value) {
    _applyOverlayStyle(_overlayStyle.copyWith(chartSeconds: value));
    _heartRateHistory.maxLength = _overlayStyle.chartSampleCount;
    persistOverlayStyle();
  }

  /// 更新折线图颜色并持久化。
  void setOverlayChartLineColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(chartLineColor: color));
    persistOverlayStyle();
  }

  /// 更新折线图高度(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayChartHeight(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(chartHeight: value.clamp(40.0, 160.0)));
  }

  /// 更新折线图与内容的间距(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayChartSpacing(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(chartSpacing: value.clamp(0.0, 24.0)));
  }

  /// 更新心形脉冲开关并持久化。
  void setOverlayHeartPulseEnabled(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(heartPulseEnabled: value));
    persistOverlayStyle();
  }

  /// 更新文字律动开关并持久化。
  void setOverlayTextPulseEnabled(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(textPulseEnabled: value));
    persistOverlayStyle();
  }

  /// 更新辉光半径倍率(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayGlowRadius(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(glowRadius: value.clamp(0.0, 3.0)));
  }

  /// 更新辉光透明度倍率(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayGlowOpacity(double value) {
    _applyOverlayStyle(
        _overlayStyle.copyWith(glowOpacity: value.clamp(0.0, 1.0)));
  }

  /// 将 ARGB 十六进制字符串解析为 Color,非法值回退 [fallback]。
  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) {
      return fallback;
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } on FormatException {
      return fallback;
    }
  }

  /// 更新心率数字位置并持久化。
  void setOverlayBpmPosition(BpmPosition position) {
    _applyOverlayStyle(_overlayStyle.copyWith(bpmPosition: position));
    persistOverlayStyle();
  }

  /// 更新心电图样式并持久化。
  void setOverlayEcgStyle(EcgStyle style) {
    _applyOverlayStyle(_overlayStyle.copyWith(ecgStyle: style));
    persistOverlayStyle();
  }

  /// 将当前样式应用到各显示端并通知 UI。
  void _applyOverlayStyle(OverlayStyle style) {
    if (_overlayStyle == style) return;
    _overlayStyle = style;
    notifyListeners();
    _desktopOverlay?.setStyle(style);
    _androidDisplay?.setStyle(style);
  }

  /// 将当前样式持久化。
  Future<void> persistOverlayStyle() async {
    await _settings.setValue(
        SettingsKeys.overlayHeartSize, _overlayStyle.heartSize);
    await _settings.setValue(
        SettingsKeys.overlayBpmFontSize, _overlayStyle.bpmFontSize);
    await _settings.setValue(
        SettingsKeys.overlayBpmPosition, _overlayStyle.bpmPosition.name);
    await _settings.setValue(
        SettingsKeys.overlayEcgStyle, _overlayStyle.ecgStyle.name);
    await _settings.setValue(SettingsKeys.overlayGap, _overlayStyle.gap);
    await _settings.setValue(
        SettingsKeys.overlayOpacity, _overlayStyle.opacity);
    await _settings.setValue(
        SettingsKeys.overlayBackgroundOpacity, _overlayStyle.backgroundOpacity);
    await _settings.setValue(SettingsKeys.overlayBackgroundColor,
        _overlayStyle.backgroundColor.toARGB32().toRadixString(16));
    await _settings.setValue(
        SettingsKeys.overlayBackgroundWidth, _overlayStyle.backgroundWidth);
    await _settings.setValue(
        SettingsKeys.overlayBackgroundHeight, _overlayStyle.backgroundHeight);
    await _settings.setValue(SettingsKeys.overlayTextColor,
        _overlayStyle.textColor.toARGB32().toRadixString(16));
    await _settings.setValue(SettingsKeys.overlayHeartColor,
        _overlayStyle.heartColor.toARGB32().toRadixString(16));
    await _settings.setValue(SettingsKeys.overlayEcgColor,
        _overlayStyle.ecgColor.toARGB32().toRadixString(16));
    await _settings.setValue(
        SettingsKeys.overlayShowChart, _overlayStyle.showChart);
    await _settings.setValue(
        SettingsKeys.overlayChartSeconds, _overlayStyle.chartSeconds);
    await _settings.setValue(SettingsKeys.overlayChartLineColor,
        _overlayStyle.chartLineColor.toARGB32().toRadixString(16));
    await _settings.setValue(
        SettingsKeys.overlayChartHeight, _overlayStyle.chartHeight);
    await _settings.setValue(
        SettingsKeys.overlayChartSpacing, _overlayStyle.chartSpacing);
    await _settings.setValue(
        SettingsKeys.overlayShowBpmLabel, _overlayStyle.showBpmLabel);
    await _settings.setValue(
        SettingsKeys.overlayShowChart, _overlayStyle.showChart);
    await _settings.setValue(
        SettingsKeys.overlayTextWeight, _overlayStyle.textWeight);
    await _settings.setValue(SettingsKeys.overlayTextFontFamily,
        _overlayStyle.textFontFamily);
    await _settings.setValue(SettingsKeys.overlayHeartPulseEnabled,
        _overlayStyle.heartPulseEnabled);
    await _settings.setValue(
        SettingsKeys.overlayTextPulseEnabled, _overlayStyle.textPulseEnabled);
    await _settings.setValue(
        SettingsKeys.overlayGlowRadius, _overlayStyle.glowRadius);
    await _settings.setValue(
        SettingsKeys.overlayGlowOpacity, _overlayStyle.glowOpacity);
  }

  @override
  void dispose() {
    _readingsSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }
}
