import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置的持久化仓库。
///
/// 抽象为键值读写,便于在测试中替换为内存实现。
abstract interface class SettingsRepository {
  /// 读取全部已知设置项;未设置过的键返回 null。
  Future<Map<String, Object?>> loadAll();

  /// 写入一项设置;支持 bool / double / String / null(删除)。
  Future<void> setValue(String key, Object? value);
}

/// 设置项键名。
abstract final class SettingsKeys {
  /// 模拟心率场景(枚举名:low / medium / high)。
  static const simulatedScenario = 'simulated.scenario';

  /// 上次连接的心率设备 ID(Android 为 MAC,iOS / macOS 为系统 UUID)。
  static const bleLastDeviceId = 'ble.last_device_id';

  /// 上次连接的心率设备名称(用于断开后广播不再携带名称时展示)。
  static const bleLastDeviceName = 'ble.last_device_name';

  /// 界面主题模式(枚举名:system / light / dark)。
  static const themeMode = 'app.theme_mode';

  /// OBS 浏览器源本地服务开关。
  static const obsOverlayEnabled = 'obs_overlay.enabled';

  /// 桌面悬浮窗开关(Windows / macOS)。
  static const desktopOverlayEnabled = 'desktop_overlay.enabled';

  /// 桌面悬浮窗鼠标穿透开关。
  static const mousePassthroughEnabled = 'desktop_overlay.mouse_passthrough';

  /// macOS 菜单栏心率显示开关。
  static const menubarEnabled = 'menubar.enabled';

  /// Android 悬浮窗开关。
  static const androidOverlayEnabled = 'android_overlay.enabled';

  /// Android 状态栏(持续通知)心率显示开关。
  static const statusBarEnabled = 'status_bar.enabled';

  /// 悬浮窗心形大小(逻辑像素)。
  static const overlayHeartSize = 'overlay.heart_size';

  /// 悬浮窗心率数字字号(逻辑像素)。
  static const overlayBpmFontSize = 'overlay.bpm_font_size';

  /// 悬浮窗心率数字位置(枚举名)。
  static const overlayBpmPosition = 'overlay.bpm_position';

  /// 悬浮窗心电图样式(枚举名)。
  static const overlayEcgStyle = 'overlay.ecg_style';

  /// 悬浮窗心形与数字的间距(逻辑像素)。
  static const overlayGap = 'overlay.gap';

  /// 悬浮窗心率内容(心形 + 数字)不透明度(0.1 ~ 1.0)。
  static const overlayOpacity = 'overlay.opacity';

  /// 悬浮窗背景板不透明度(0.0 = 无背景板,1.0 = 不透明)。
  static const overlayBackgroundOpacity = 'overlay.background_opacity';

  /// 悬浮窗背景板颜色(ARGB 十六进制字符串)。
  static const overlayBackgroundColor = 'overlay.background_color';

  /// 悬浮窗背景板宽度(逻辑像素)。
  static const overlayBackgroundWidth = 'overlay.background_width';

  /// 悬浮窗背景板高度(逻辑像素)。
  static const overlayBackgroundHeight = 'overlay.background_height';

  /// 悬浮窗心率数字文字颜色(ARGB 十六进制字符串)。
  static const overlayTextColor = 'overlay.text_color';

  /// 悬浮窗心形颜色(ARGB 十六进制字符串)。
  static const overlayHeartColor = 'overlay.heart_color';

  /// 悬浮窗心电图线颜色(ARGB 十六进制字符串)。
  static const overlayEcgColor = 'overlay.ecg_color';

  /// 是否显示近期心率波动折线图。
  static const overlayShowChart = 'overlay.show_chart';

  /// 折线图采集时长(秒,10 ~ 120)。
  static const overlayChartSeconds = 'overlay.chart_seconds';

  /// 折线图颜色(ARGB 十六进制字符串)。
  static const overlayChartLineColor = 'overlay.chart_line_color';

  /// 折线图高度(逻辑像素,40 ~ 160)。
  static const overlayChartHeight = 'overlay.chart_height';

  /// 折线图与内容的间距(逻辑像素,0 ~ 24)。
  static const overlayChartSpacing = 'overlay.chart_spacing';

  /// 是否显示 “bpm” 标签。
  static const overlayShowBpmLabel = 'overlay.show_bpm_label';

  /// 悬浮窗数字字重(100 ~ 900)。
  static const overlayTextWeight = 'overlay.text_weight';

  /// 悬浮窗数字字体族;空 = 系统默认。
  static const overlayTextFontFamily = 'overlay.text_font_family';

  /// 心形是否脉冲缩放。
  static const overlayHeartPulseEnabled = 'overlay.heart_pulse_enabled';

  /// 心率数字是否脉冲律动。
  static const overlayTextPulseEnabled = 'overlay.text_pulse_enabled';

  /// 辉光半径倍率(0.0 ~ 3.0)。
  static const overlayGlowRadius = 'overlay.glow_radius';

  /// 辉光透明度倍率(0.0 ~ 1.0)。
  static const overlayGlowOpacity = 'overlay.glow_opacity';
}

/// 基于 [SharedPreferencesAsync] 的设置仓库实现。
class SharedPreferencesSettingsRepository implements SettingsRepository {
  /// 创建仓库;[prefs] 可注入用于测试。
  SharedPreferencesSettingsRepository({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// 已知键与其值类型的注册表,驱动 loadAll 的类型化读取。
  static const Map<String, String> _knownKeys = {
    SettingsKeys.simulatedScenario: 'string',
    SettingsKeys.bleLastDeviceId: 'string',
    SettingsKeys.bleLastDeviceName: 'string',
    SettingsKeys.themeMode: 'string',
    SettingsKeys.obsOverlayEnabled: 'bool',
    SettingsKeys.desktopOverlayEnabled: 'bool',
    SettingsKeys.mousePassthroughEnabled: 'bool',
    SettingsKeys.menubarEnabled: 'bool',
    SettingsKeys.androidOverlayEnabled: 'bool',
    SettingsKeys.statusBarEnabled: 'bool',
    SettingsKeys.overlayHeartSize: 'double',
    SettingsKeys.overlayBpmFontSize: 'double',
    SettingsKeys.overlayBpmPosition: 'string',
    SettingsKeys.overlayEcgStyle: 'string',
    SettingsKeys.overlayGap: 'double',
    SettingsKeys.overlayOpacity: 'double',
    SettingsKeys.overlayBackgroundOpacity: 'double',
    SettingsKeys.overlayBackgroundColor: 'string',
    SettingsKeys.overlayBackgroundWidth: 'double',
    SettingsKeys.overlayBackgroundHeight: 'double',
    SettingsKeys.overlayTextColor: 'string',
    SettingsKeys.overlayHeartColor: 'string',
    SettingsKeys.overlayEcgColor: 'string',
    SettingsKeys.overlayShowBpmLabel: 'bool',
    SettingsKeys.overlayTextWeight: 'double',
    SettingsKeys.overlayTextFontFamily: 'string',
    SettingsKeys.overlayShowChart: 'bool',
    SettingsKeys.overlayChartSeconds: 'double',
    SettingsKeys.overlayChartLineColor: 'string',
    SettingsKeys.overlayChartHeight: 'double',
    SettingsKeys.overlayChartSpacing: 'double',
    SettingsKeys.overlayHeartPulseEnabled: 'bool',
    SettingsKeys.overlayTextPulseEnabled: 'bool',
    SettingsKeys.overlayGlowRadius: 'double',
    SettingsKeys.overlayGlowOpacity: 'double',
  };

  @override
  Future<Map<String, Object?>> loadAll() async {
    final values = <String, Object?>{};
    for (final entry in _knownKeys.entries) {
      switch (entry.value) {
        case 'bool':
          values[entry.key] = await _prefs.getBool(entry.key);
        case 'double':
          values[entry.key] = await _prefs.getDouble(entry.key);
        case 'string':
          values[entry.key] = await _prefs.getString(entry.key);
      }
    }
    return values;
  }

  @override
  Future<void> setValue(String key, Object? value) async {
    switch (value) {
      case null:
        await _prefs.remove(key);
      case bool():
        await _prefs.setBool(key, value);
      case double():
        await _prefs.setDouble(key, value);
      case String():
        await _prefs.setString(key, value);
      default:
        throw ArgumentError.value(
          value,
          'value',
          '仅支持 bool/double/String/null',
        );
    }
  }
}
