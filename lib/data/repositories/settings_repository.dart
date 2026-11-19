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

  /// 心率数据源模式(枚举名:real / simulated)。
  static const heartRateMode = 'heart_rate.mode';

  /// 上次连接的心率设备 ID(Android 为 MAC,iOS / macOS 为系统 UUID)。
  static const bleLastDeviceId = 'ble.last_device_id';

  /// 上次连接的心率设备名称(用于断开后广播不再携带名称时展示)。
  static const bleLastDeviceName = 'ble.last_device_name';

  /// 界面主题模式(枚举名:system / light / dark)。
  static const themeMode = 'app.theme_mode';

  /// 全局字体族;未设置 = 系统默认。应用界面与悬浮窗默认字体。
  static const globalFontFamily = 'app.font_family';

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

  /// Android 悬浮窗触摸穿透开关(触摸作用于下层应用)。
  static const androidOverlayTouchPassthrough =
      'android_overlay.touch_passthrough';

  /// Android 悬浮窗拖动边缘吸附开关。
  static const androidOverlayEdgeSnap = 'android_overlay.edge_snap';

  /// Android 悬浮窗上次位置 X(逻辑像素)。
  static const androidOverlayX = 'android_overlay.x';

  /// Android 悬浮窗上次位置 Y(逻辑像素)。
  static const androidOverlayY = 'android_overlay.y';

  /// 悬浮窗心形大小(逻辑像素)。
  static const overlayHeartSize = 'overlay.heart_size';

  /// 悬浮窗心率数字字号(逻辑像素)。
  static const overlayBpmFontSize = 'overlay.bpm_font_size';

  /// 悬浮窗心率数字位置(枚举名)。
  static const overlayBpmPosition = 'overlay.bpm_position';

  /// 悬浮窗心电图样式(枚举名)。
  static const overlayEcgStyle = 'overlay.ecg_style';

  /// 悬浮窗心形与数字的间距(逻辑像素)。
  static const overlayHeartTextGap = 'overlay.heart_text_gap';

  /// 悬浮窗心率内容(心形 + 数字)整体不透明度(0.1 ~ 1.0)。
  static const overlayContentOpacity = 'overlay.content_opacity';

  /// 悬浮窗背景板不透明度(0.0 = 无背景板,1.0 = 不透明)。
  static const overlayBackgroundOpacity = 'overlay.background_opacity';

  /// 悬浮窗背景板颜色(ARGB 十六进制字符串)。
  static const overlayBackgroundColor = 'overlay.background_color';

  /// 悬浮窗背景板宽度(逻辑像素)。
  static const overlayBackgroundWidth = 'overlay.background_width';

  /// 悬浮窗背景板高度(逻辑像素)。
  static const overlayBackgroundHeight = 'overlay.background_height';

  /// 悬浮窗心率数字颜色(ARGB 十六进制字符串)。
  static const overlayBpmColor = 'overlay.bpm_color';

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
  static const overlayBpmWeight = 'overlay.bpm_weight';

  /// 悬浮窗数字字体族;空 = 系统默认。
  static const overlayBpmFontFamily = 'overlay.bpm_font_family';

  /// 心形是否脉冲缩放。
  static const overlayHeartPulseEnabled = 'overlay.heart_pulse_enabled';

  /// 心率数字是否脉冲律动。
  static const overlayBpmPulseEnabled = 'overlay.bpm_pulse_enabled';

  /// 心跳辉光开关。
  static const overlayGlowEnabled = 'overlay.glow_enabled';

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
    SettingsKeys.heartRateMode: 'string',
    SettingsKeys.bleLastDeviceId: 'string',
    SettingsKeys.bleLastDeviceName: 'string',
    SettingsKeys.themeMode: 'string',
    SettingsKeys.globalFontFamily: 'string',
    SettingsKeys.obsOverlayEnabled: 'bool',
    SettingsKeys.desktopOverlayEnabled: 'bool',
    SettingsKeys.mousePassthroughEnabled: 'bool',
    SettingsKeys.menubarEnabled: 'bool',
    SettingsKeys.androidOverlayEnabled: 'bool',
    SettingsKeys.statusBarEnabled: 'bool',
    SettingsKeys.androidOverlayTouchPassthrough: 'bool',
    SettingsKeys.androidOverlayEdgeSnap: 'bool',
    SettingsKeys.androidOverlayX: 'double',
    SettingsKeys.androidOverlayY: 'double',
    SettingsKeys.overlayHeartSize: 'double',
    SettingsKeys.overlayBpmFontSize: 'double',
    SettingsKeys.overlayBpmPosition: 'string',
    SettingsKeys.overlayEcgStyle: 'string',
    SettingsKeys.overlayHeartTextGap: 'double',
    SettingsKeys.overlayContentOpacity: 'double',
    SettingsKeys.overlayBackgroundOpacity: 'double',
    SettingsKeys.overlayBackgroundColor: 'string',
    SettingsKeys.overlayBackgroundWidth: 'double',
    SettingsKeys.overlayBackgroundHeight: 'double',
    SettingsKeys.overlayBpmColor: 'string',
    SettingsKeys.overlayHeartColor: 'string',
    SettingsKeys.overlayEcgColor: 'string',
    SettingsKeys.overlayShowBpmLabel: 'bool',
    SettingsKeys.overlayBpmWeight: 'double',
    SettingsKeys.overlayBpmFontFamily: 'string',
    SettingsKeys.overlayShowChart: 'bool',
    SettingsKeys.overlayChartSeconds: 'double',
    SettingsKeys.overlayChartLineColor: 'string',
    SettingsKeys.overlayChartHeight: 'double',
    SettingsKeys.overlayChartSpacing: 'double',
    SettingsKeys.overlayHeartPulseEnabled: 'bool',
    SettingsKeys.overlayBpmPulseEnabled: 'bool',
    SettingsKeys.overlayGlowEnabled: 'bool',
    SettingsKeys.overlayGlowRadius: 'double',
    SettingsKeys.overlayGlowOpacity: 'double',
  };

  /// 旧键名 → 现键名。
  ///
  /// 这些字段在命名梳理时改过名(如 `overlay.opacity` 语义实为「内容整体
  /// 不透明度」)。旧键只在首次读取时迁移一次,之后删除,避免用户升级后
  /// 悬浮窗样式被静默重置。
  static const Map<String, String> _legacyKeys = {
    'overlay.gap': SettingsKeys.overlayHeartTextGap,
    'overlay.opacity': SettingsKeys.overlayContentOpacity,
    'overlay.text_color': SettingsKeys.overlayBpmColor,
    'overlay.text_weight': SettingsKeys.overlayBpmWeight,
    'overlay.text_font_family': SettingsKeys.overlayBpmFontFamily,
    'overlay.text_pulse_enabled': SettingsKeys.overlayBpmPulseEnabled,
  };

  @override
  Future<Map<String, Object?>> loadAll() async {
    final values = <String, Object?>{};
    for (final entry in _knownKeys.entries) {
      values[entry.key] = await _read(entry.key, entry.value);
    }
    await _migrateLegacyKeys(values);
    return values;
  }

  /// 按类型读取单个键。
  Future<Object?> _read(String key, String type) async {
    switch (type) {
      case 'bool':
        return _prefs.getBool(key);
      case 'double':
        return _prefs.getDouble(key);
      case 'string':
        return _prefs.getString(key);
    }
    return null;
  }

  /// 把旧键名的值搬到新键名(仅当新键为空时),随后删除旧键。
  Future<void> _migrateLegacyKeys(Map<String, Object?> values) async {
    for (final entry in _legacyKeys.entries) {
      final legacyKey = entry.key;
      final currentKey = entry.value;
      if (values[currentKey] != null) continue;
      final legacyValue = await _read(legacyKey, _knownKeys[currentKey]!);
      if (legacyValue == null) continue;
      await setValue(currentKey, legacyValue);
      await _prefs.remove(legacyKey);
      values[currentKey] = legacyValue;
    }
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
