import 'dart:async';
import 'dart:ui' show Color, Offset;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/ble_heart_rate_transport.dart';
import '../../../../data/services/platform/android_display_service.dart';
import '../../../../data/services/platform/desktop_overlay_service.dart';
import '../../../../data/services/platform/font_list_service.dart';
import '../../../../data/services/platform/macos_app_menu_service.dart';
import '../../../../data/services/platform/macos_menubar_service.dart';
import '../../../../data/services/platform/obs_overlay_service.dart';
import '../../../../data/services/heart_rate_mode_source.dart';
import '../../../../data/services/heart_rate_scenario_source.dart';
import '../../../../data/repositories/heart_rate_repository.dart';
import '../../../../domain/models/heart_rate_connection.dart';
import '../../../../domain/models/heart_rate_device.dart';
import '../../../../domain/models/heart_rate_reading.dart';
import '../../../../domain/models/heart_rate_history.dart';
import '../../../../domain/models/heart_rate_mode.dart';
import '../../../../domain/models/heart_rate_scenario.dart';
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
    this._appMenu,
    this._androidDisplay,
    this._obsOverlay,
    FontListService? fontListService,
  }) : _fontList = fontListService ?? FontListService();

  final HeartRateRepository _repository;
  final SettingsRepository _settings;
  final DesktopOverlay? _desktopOverlay;
  final MenubarDisplay? _menubar;
  final AppMenuDisplay? _appMenu;
  final AndroidDisplay? _androidDisplay;
  final ObsOverlayDisplay? _obsOverlay;
  final FontListService _fontList;

  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;
  StreamSubscription<List<HeartRateDevice>>? _devicesSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<String>? _errorsSub;
  StreamSubscription<HeartRateMode>? _modeSub;

  bool _initialized = false;

  HeartRateModeSource? _modeSource;

  HeartRateMode _mode = HeartRateMode.real;

  bool _switchingMode = false;

  HeartRateConnection _connection = HeartRateConnection.disconnected;

  int? _bpm;

  HeartRateDevice? _connectedDevice;

  String? _lastDeviceId;

  String? _lastDeviceName;

  List<HeartRateDevice> _devices = const [];

  bool _showAllDevices = false;

  bool _isScanning = false;

  String? _scanError;

  String? _connectionError;

  ThemeMode _themeMode = ThemeMode.system;

  /// 全局字体族;null = 系统默认。应用界面与悬浮窗的默认字体。
  String? _globalFontFamily;

  /// 模拟场景能力;真实模式下隐藏场景 UI。
  HeartRateScenarioSource? _scenarioSource;

  HeartRateScenario _scenario = HeartRateScenario.medium;

  bool _desktopOverlayEnabled = false;

  bool _mousePassthroughEnabled = false;

  bool _menubarEnabled = false;

  bool _androidOverlayEnabled = false;

  bool _androidTouchPassthroughEnabled = false;

  bool _androidEdgeSnapEnabled = true;

  /// 悬浮窗上次位置(逻辑像素);null = 尚未记录。
  Offset? _androidOverlayPosition;

  StreamSubscription<Offset>? _overlayPositionSub;

  bool _statusBarEnabled = false;

  bool _obsOverlayEnabled = false;

  OverlayStyle _overlayStyle = OverlayStyle.defaults;

  /// 近期心率采样历史(供主界面预览折线图使用)。
  final HeartRateHistory _heartRateHistory = HeartRateHistory();

  /// 近期心率采样历史(只读)。
  HeartRateHistory get heartRateHistory => _heartRateHistory;

  /// 是否支持桌面悬浮窗(macOS / Windows)。
  bool get supportsDesktopOverlay => _desktopOverlay != null;

  /// 是否支持 macOS 菜单栏显示。
  bool get supportsMenubar => _menubar != null;

  /// 是否支持 Android 显示端(悬浮窗 / 状态栏)。
  bool get supportsAndroidDisplay => _androidDisplay != null;

  /// 是否支持 OBS 浏览器源(macOS / Windows)。
  bool get supportsObsOverlay => _obsOverlay != null;

  /// 当前连接状态。
  HeartRateConnection get connection => _connection;

  /// 最近一次心率。
  int? get bpm => _bpm;

  /// 界面主题模式(跟随系统 / 浅色 / 深色)。
  ThemeMode get themeMode => _themeMode;

  /// 全局字体族;null = 系统默认。
  String? get globalFontFamily => _globalFontFamily;

  /// 当前是否为模拟模式。
  bool get isSimulatedMode => _mode == HeartRateMode.simulated;

  /// 当前数据源模式。
  HeartRateMode get mode => _mode;

  /// 是否支持在真实设备与模拟模式之间切换。
  bool get supportsModeSwitch => _modeSource != null;

  /// 是否支持模拟场景切换(仅模拟模式下展示)。
  bool get supportsScenario => isSimulatedMode && _scenarioSource != null;

  /// 当前模拟心率场景。
  HeartRateScenario get scenario => _scenario;

  /// 桌面悬浮窗开关状态。
  bool get desktopOverlayEnabled => _desktopOverlayEnabled;

  /// 鼠标穿透开关状态(仅悬浮窗开启时有效)。
  bool get mousePassthroughEnabled => _mousePassthroughEnabled;

  /// macOS 菜单栏显示开关状态。
  bool get menubarEnabled => _menubarEnabled;

  /// Android 悬浮窗开关状态。
  bool get androidOverlayEnabled => _androidOverlayEnabled;

  /// Android 悬浮窗触摸穿透开关状态。
  bool get androidTouchPassthroughEnabled => _androidTouchPassthroughEnabled;

  /// Android 悬浮窗拖动边缘吸附开关状态。
  bool get androidEdgeSnapEnabled => _androidEdgeSnapEnabled;

  /// Android 状态栏通知开关状态。
  bool get statusBarEnabled => _statusBarEnabled;

  /// OBS 浏览器源开关状态。
  bool get obsOverlayEnabled => _obsOverlayEnabled;

  /// OBS 浏览器源地址(供用户粘贴进 OBS)。
  String get obsOverlayUrl => _obsOverlay?.overlayUrl ?? '';

  /// 悬浮窗显示样式。
  OverlayStyle get overlayStyle => _overlayStyle;

  /// 实际生效的悬浮窗样式:未单独指定字体时补上全局字体。
  OverlayStyle get resolvedOverlayStyle {
    final global = _globalFontFamily;
    if (global == null || _overlayStyle.bpmFontFamily != null) {
      return _overlayStyle;
    }
    return _overlayStyle.copyWith(bpmFontFamily: global);
  }

  /// 系统已安装字体族列表(懒加载);全局字体与悬浮窗字体下拉共用。
  List<String> get fontFamilies => _fontList.fontFamilies;

  /// 是否可以发起连接(未连接时)。
  bool get canConnect => _connection == HeartRateConnection.disconnected;

  /// 是否支持扫描并选择设备(真实模式 + BLE 数据源才有该能力)。
  bool get supportsDevicePicker =>
      !isSimulatedMode && _repository.deviceScanner != null;

  /// 当前连接 / 正在连接的设备;模拟数据源或未连接时为 null。
  HeartRateDevice? get connectedDevice => _connectedDevice;

  /// 当前可连接的设备列表。
  ///
  /// 默认只保留广播了心率服务的设备,但会合并「上次连接」的设备:
  /// 小米手环断开后会停止广播名称与 0x180D 标记,仍可按系统设备 ID 重连,
  /// 若按广播内容过滤会从列表里消失。
  List<HeartRateDevice> get discoveredDevices {
    final devices = [..._devices];
    final last = _lastDevice;
    if (last != null) {
      final index = devices.indexWhere((device) => device.id == last.id);
      if (index >= 0) {
        final scanned = devices[index];
        devices[index] = HeartRateDevice(
          id: last.id,
          name: scanned.name.trim().isEmpty ? last.name : scanned.name,
          rssi: scanned.rssi,
          advertisesHeartRate: scanned.advertisesHeartRate,
          isRemembered: true,
        );
      } else {
        devices.insert(0, last);
      }
    }
    return List.unmodifiable(
      _showAllDevices
          ? devices
          : devices.where(
              (device) => device.advertisesHeartRate || device.isRemembered,
            ),
    );
  }

  /// 上次连接过的设备;尚未连接过任何设备时为 null。
  HeartRateDevice? get _lastDevice {
    final id = _lastDeviceId;
    if (id == null || id.isEmpty) return null;
    return HeartRateDevice(
      id: id,
      name: _lastDeviceName ?? '',
      isRemembered: true,
    );
  }

  /// 是否在设备选择弹窗中显示全部蓝牙设备。
  bool get showAllDevices => _showAllDevices;

  /// 是否正在扫描设备。
  bool get isScanning => _isScanning;

  /// 扫描失败提示(如蓝牙未开启)。
  String? get scanError => _scanError;

  /// 连接失败提示(如未找到心率服务、设备断开)。
  String? get connectionError => _connectionError;

  /// 初始化:订阅数据流、加载持久化设置并恢复桌面显示端。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 应用菜单:注册条目点击与状态刷新回调,须先于显示端恢复——
    // 恢复菜单栏心率时会创建状态项菜单并立即请求刷新对齐勾选态。
    _appMenu?.setToggleHandler(_onAppMenuToggle);
    _appMenu?.setRefreshHandler(_syncAppMenu);

    // 字体列表懒加载,完成后通知 UI 刷新字体下拉。
    unawaited(_fontList.load().then((_) => notifyListeners()));

    // 模式由 main.dart 按持久化值构造;无可切换能力的旧数据源则按场景能力推断。
    _modeSource = _repository.modeSource;
    _mode =
        _modeSource?.mode ??
        (_repository.scenarioSource != null
            ? HeartRateMode.simulated
            : HeartRateMode.real);
    _modeSub = _modeSource?.modeStream.listen((mode) {
      if (_mode == mode) return;
      _mode = mode;
      notifyListeners();
    });

    _connection = _repository.status;
    _bpm = _repository.currentBpm;
    // 场景由 main.dart 启动时按持久化值构造,这里读取数据源的实际状态。
    _scenarioSource = _repository.scenarioSource;
    _scenario = _scenarioSource?.scenario ?? HeartRateScenario.medium;
    _readingsSub = _repository.readings.listen((reading) {
      _bpm = reading.bpm;
      _heartRateHistory.add(reading.bpm);
      notifyListeners();
    });
    _connectionSub = _repository.connection.listen((status) {
      _connection = status;
      _connectedDevice = status == HeartRateConnection.disconnected
          ? null
          : _repository.deviceScanner?.connectedDevice;
      if (status != HeartRateConnection.connected) {
        _heartRateHistory.clear();
      }
      if (status == HeartRateConnection.disconnected) {
        _bpm = null;
      }
      if (status == HeartRateConnection.connected) {
        _connectionError = null;
        final device = _connectedDevice;
        if (device != null && device.name.trim().isNotEmpty) {
          unawaited(_rememberDevice(device));
        }
      }
      notifyListeners();
    });

    // 真实 BLE 数据源额外提供扫描结果与错误提示;模拟源没有这些流。
    final scanner = _repository.deviceScanner;
    if (scanner != null) {
      _devicesSub = scanner.scanResults.listen((devices) {
        _devices = devices;
        notifyListeners();
      });
      _scanningSub = scanner.scanningStream.listen((scanning) {
        _isScanning = scanning;
        notifyListeners();
      });
      _errorsSub = scanner.errors.listen((message) {
        _connectionError = message;
        notifyListeners();
      });
    }

    final values = await _settings.loadAll();
    _lastDeviceId = values[SettingsKeys.bleLastDeviceId] as String?;
    _lastDeviceName = values[SettingsKeys.bleLastDeviceName] as String?;
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == values[SettingsKeys.themeMode],
      orElse: () => ThemeMode.system,
    );
    _globalFontFamily = values[SettingsKeys.globalFontFamily] as String?;
    _desktopOverlayEnabled =
        (values[SettingsKeys.desktopOverlayEnabled] as bool?) ?? false;
    _mousePassthroughEnabled =
        (values[SettingsKeys.mousePassthroughEnabled] as bool?) ?? false;
    // 菜单栏心率默认显示(用户关闭过则以持久化值为准)。
    _menubarEnabled = (values[SettingsKeys.menubarEnabled] as bool?) ?? true;
    _androidOverlayEnabled =
        (values[SettingsKeys.androidOverlayEnabled] as bool?) ?? false;
    _statusBarEnabled =
        (values[SettingsKeys.statusBarEnabled] as bool?) ?? false;
    _androidTouchPassthroughEnabled =
        (values[SettingsKeys.androidOverlayTouchPassthrough] as bool?) ?? false;
    // 边缘吸附默认开启:手机上半透明浮层贴在屏幕边缘更不容易挡住内容。
    _androidEdgeSnapEnabled =
        (values[SettingsKeys.androidOverlayEdgeSnap] as bool?) ?? true;
    final overlayX = values[SettingsKeys.androidOverlayX] as double?;
    final overlayY = values[SettingsKeys.androidOverlayY] as double?;
    if (overlayX != null && overlayY != null) {
      _androidOverlayPosition = Offset(overlayX, overlayY);
    }
    _obsOverlayEnabled =
        (values[SettingsKeys.obsOverlayEnabled] as bool?) ?? false;
    _overlayStyle = OverlayStyle(
      heartSize: (values[SettingsKeys.overlayHeartSize] as double?) ?? 64,
      bpmFontSize: (values[SettingsKeys.overlayBpmFontSize] as double?) ?? 20,
      bpmPosition: BpmPosition.fromString(
        values[SettingsKeys.overlayBpmPosition] as String?,
      ),
      ecgStyle: EcgStyle.fromString(
        values[SettingsKeys.overlayEcgStyle] as String?,
      ),
      heartTextGap: (values[SettingsKeys.overlayHeartTextGap] as double?) ?? 6,
      contentOpacity:
          (values[SettingsKeys.overlayContentOpacity] as double?) ?? 1.0,
      backgroundOpacity:
          (values[SettingsKeys.overlayBackgroundOpacity] as double?) ?? 0.0,
      backgroundColor: _colorFromHex(
        values[SettingsKeys.overlayBackgroundColor] as String?,
        OverlayStyle.defaultBackgroundColor,
      ),
      backgroundWidth:
          (values[SettingsKeys.overlayBackgroundWidth] as double?) ?? 130,
      backgroundHeight:
          (values[SettingsKeys.overlayBackgroundHeight] as double?) ?? 170,
      bpmColor: _colorFromHex(
        values[SettingsKeys.overlayBpmColor] as String?,
        OverlayStyle.defaultTextColor,
      ),
      heartColor: _colorFromHex(
        values[SettingsKeys.overlayHeartColor] as String?,
        OverlayStyle.defaultHeartColor,
      ),
      ecgColor: _colorFromHex(
        values[SettingsKeys.overlayEcgColor] as String?,
        OverlayStyle.defaultEcgColor,
      ),
      showChart: (values[SettingsKeys.overlayShowChart] as bool?) ?? false,
      chartSeconds: (values[SettingsKeys.overlayChartSeconds] as double?) ?? 30,
      chartLineColor: _colorFromHex(
        values[SettingsKeys.overlayChartLineColor] as String?,
        OverlayStyle.defaultChartLineColor,
      ),
      chartHeight: (values[SettingsKeys.overlayChartHeight] as double?) ?? 84,
      chartSpacing: (values[SettingsKeys.overlayChartSpacing] as double?) ?? 8,
      showBpmLabel: (values[SettingsKeys.overlayShowBpmLabel] as bool?) ?? true,
      bpmWeight: (values[SettingsKeys.overlayBpmWeight] as double?) ?? 700,
      bpmFontFamily: values[SettingsKeys.overlayBpmFontFamily] as String?,
      heartPulseEnabled:
          (values[SettingsKeys.overlayHeartPulseEnabled] as bool?) ?? true,
      bpmPulseEnabled:
          (values[SettingsKeys.overlayBpmPulseEnabled] as bool?) ?? true,
      glowEnabled: (values[SettingsKeys.overlayGlowEnabled] as bool?) ?? true,
      glowRadius:
          (values[SettingsKeys.overlayGlowRadius] as double?)?.clamp(
            0.0,
            3.0,
          ) ??
          1.0,
      glowOpacity:
          (values[SettingsKeys.overlayGlowOpacity] as double?)?.clamp(
            0.0,
            1.0,
          ) ??
          0.5,
    );
    notifyListeners();

    // 恢复上次会话开启的显示端(Android 悬浮窗需手动开启)。
    if (_desktopOverlayEnabled) {
      await _desktopOverlay?.show(passthrough: _mousePassthroughEnabled);
      await _desktopOverlay?.setStyle(resolvedOverlayStyle);
    }
    if (_menubarEnabled) {
      await _menubar?.setEnabled(true);
    }
    if (_androidOverlayEnabled && _androidDisplay != null) {
      // 恢复上次开启的悬浮窗。权限被系统收回时回落为关闭,避免出现
      // 「开关是开的、屏幕上却没有悬浮窗」的假状态。
      final granted = await _androidDisplay.ensureOverlayPermission();
      if (granted) {
        await _androidDisplay.showOverlay(
          position: _androidOverlayPosition,
          touchPassthrough: _androidTouchPassthroughEnabled,
          edgeSnap: _androidEdgeSnapEnabled,
        );
      } else {
        _androidOverlayEnabled = false;
        await _settings.setValue(SettingsKeys.androidOverlayEnabled, false);
      }
      notifyListeners();
    }
    if (_statusBarEnabled) {
      await _androidDisplay?.setStatusBarEnabled(true);
    }
    if (_obsOverlayEnabled) {
      // 端口被占用等启动失败时回落为关闭,不保留虚假的开启状态。
      final ok = await _obsOverlay?.setEnabled(true) ?? false;
      if (ok) {
        await _obsOverlay?.setStyle(resolvedOverlayStyle);
      } else {
        _obsOverlayEnabled = false;
      }
    }
    await _androidDisplay?.setStyle(resolvedOverlayStyle);

    // Android 悬浮窗:把上次的穿透/吸附/位置状态交给显示端,并订阅位置回传。
    final android = _androidDisplay;
    if (android != null) {
      _overlayPositionSub = android.overlayPositionStream.listen(
        _onOverlayPositionChanged,
      );
    }
    _heartRateHistory.maxLength = _overlayStyle.chartSampleCount;
    notifyListeners();

    // 推送初始状态到应用菜单(状态项未创建时为无害写入)。
    unawaited(_syncAppMenu());

    // 以模拟模式启动时自动开始模拟,免去再点一次「开始模拟」。
    if (_modeSource != null &&
        isSimulatedMode &&
        _connection == HeartRateConnection.disconnected) {
      unawaited(connect());
    }
  }

  /// 直接连接数据源。
  ///
  /// 真实 BLE 源会自动挑选信号最强的心率广播设备;带设备选择能力的源
  /// 通常由 [beginDeviceScan] + [connectToDevice] 驱动。
  Future<void> connect() async {
    _connectionError = null;
    notifyListeners();
    await _repository.connect();
  }

  /// 切换真实 / 模拟模式。
  ///
  /// 底层 [HeartRateModeSource] 负责先断开旧模式的数据源,两者互斥;
  /// 切到模拟模式后自动开始模拟,切到真实模式则由用户选择设备连接。
  Future<void> setMode(HeartRateMode mode) async {
    final source = _modeSource;
    if (source == null || mode == _mode || _switchingMode) return;
    _switchingMode = true;
    _connectionError = null;
    _scanError = null;
    _isScanning = false;
    _devices = const [];
    notifyListeners();
    try {
      await source.setMode(mode);
      _mode = source.mode;
      _connectedDevice = null;
      _bpm = null;
      _heartRateHistory.clear();
      await _settings.setValue(SettingsKeys.heartRateMode, mode.name);
      notifyListeners();
      if (mode == HeartRateMode.simulated) {
        await connect();
      }
    } finally {
      _switchingMode = false;
      notifyListeners();
    }
  }

  /// 停止模拟并回到真实设备模式。
  Future<void> stopSimulation() => setMode(HeartRateMode.real);

  /// 开始设备扫描(打开设备选择弹窗时调用):清空旧结果与过滤条件。
  Future<void> beginDeviceScan() => _startDeviceScan(resetFilter: true);

  /// 重新扫描:保留「显示全部蓝牙设备」开关状态。
  Future<void> rescanDevices() => _startDeviceScan(resetFilter: false);

  Future<void> _startDeviceScan({required bool resetFilter}) async {
    final scanner = _repository.deviceScanner;
    if (scanner == null) return;
    if (resetFilter) {
      _showAllDevices = false;
      _devices = const [];
    }
    _scanError = null;
    _connectionError = null;
    _isScanning = true;
    notifyListeners();
    try {
      await scanner.startScan();
    } on Object catch (error) {
      _scanError = _describeError(error);
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 停止扫描(关闭设备选择弹窗时调用)。
  Future<void> stopDeviceScan() async {
    final scanner = _repository.deviceScanner;
    if (scanner == null) return;
    await scanner.stopScan();
    _isScanning = scanner.isScanning;
    notifyListeners();
  }

  /// 切换「显示全部蓝牙设备」;开启后不再过滤未声明心率服务的设备。
  void setShowAllDevices(bool value) {
    if (_showAllDevices == value) return;
    _showAllDevices = value;
    notifyListeners();
  }

  /// 连接用户选中的设备;连接结果通过连接状态与 [connectionError] 反馈。
  Future<void> connectToDevice(HeartRateDevice device) async {
    final scanner = _repository.deviceScanner;
    if (scanner == null) return;
    _scanError = null;
    _connectionError = null;
    _isScanning = false;
    unawaited(_rememberDevice(device));
    notifyListeners();
    await scanner.connectTo(device);
  }

  /// 记住本次连接 / 尝试连接的设备,便于断开后直接重连。
  Future<void> _rememberDevice(HeartRateDevice device) async {
    final name = device.displayName == '未命名设备' ? '' : device.displayName;
    if (_lastDeviceId == device.id && (_lastDeviceName ?? '') == name) {
      return;
    }
    _lastDeviceId = device.id;
    _lastDeviceName = name;
    await _settings.setValue(SettingsKeys.bleLastDeviceId, device.id);
    await _settings.setValue(SettingsKeys.bleLastDeviceName, name);
  }

  /// 切换模拟心率场景并持久化;数据源不支持场景时为空操作。
  Future<void> setScenario(HeartRateScenario scenario) async {
    final source = _scenarioSource;
    if (source == null || _scenario == scenario) return;
    source.setScenario(scenario);
    _scenario = scenario;
    notifyListeners();
    await _settings.setValue(SettingsKeys.simulatedScenario, scenario.name);
  }

  /// 断开设备。
  Future<void> disconnect() async {
    _connectionError = null;
    _connectedDevice = null;
    _bpm = null;
    await _repository.disconnect();
    notifyListeners();
  }

  /// 切换界面主题模式(跟随系统 / 浅色 / 深色)并持久化。
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _settings.setValue(SettingsKeys.themeMode, mode.name);
  }

  /// 设置全局字体(应用界面 + 悬浮窗默认字体)并持久化;null = 系统默认。
  Future<void> setGlobalFontFamily(String? family) async {
    if (_globalFontFamily == family) return;
    _globalFontFamily = family;
    notifyListeners();
    await _settings.setValue(SettingsKeys.globalFontFamily, family);
    // 悬浮窗字体未单独指定时随全局字体变化,重新下发生效样式。
    _pushOverlayStyle();
  }

  /// 开关桌面悬浮窗(平台不支持时为空操作)。
  Future<void> setDesktopOverlayEnabled(bool value) async {
    if (!supportsDesktopOverlay) return;
    if (_desktopOverlayEnabled == value) return;
    _desktopOverlayEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.desktopOverlayEnabled, value);
    if (value) {
      await _desktopOverlay?.show(passthrough: _mousePassthroughEnabled);
    } else {
      await _desktopOverlay?.hide();
    }
    unawaited(_syncAppMenu());
  }

  /// 开关鼠标穿透。
  Future<void> setMousePassthroughEnabled(bool value) async {
    if (_mousePassthroughEnabled == value) return;
    _mousePassthroughEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.mousePassthroughEnabled, value);
    await _desktopOverlay?.setPassthrough(value);
    unawaited(_syncAppMenu());
  }

  /// 开关 macOS 菜单栏心率显示。
  Future<void> setMenubarEnabled(bool value) async {
    if (_menubarEnabled == value) return;
    _menubarEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.menubarEnabled, value);
    await _menubar?.setEnabled(value);
    unawaited(_syncAppMenu());
  }

  /// 开关 Android 悬浮窗;权限未授予时返回 false 并不改变开关状态。
  Future<bool> setAndroidOverlayEnabled(bool value) async {
    if (_androidOverlayEnabled == value) return true;
    if (value) {
      final granted = await _androidDisplay?.ensureOverlayPermission() ?? false;
      if (!granted) return false;
      // 显示时带入上次位置与当前交互选项。
      await _androidDisplay?.showOverlay(
        position: _androidOverlayPosition,
        touchPassthrough: _androidTouchPassthroughEnabled,
        edgeSnap: _androidEdgeSnapEnabled,
      );
    } else {
      await _androidDisplay?.hideOverlay();
    }
    _androidOverlayEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.androidOverlayEnabled, value);
    return true;
  }

  /// 悬浮窗位置变化:记录并持久化,下次显示从该位置恢复。
  void _onOverlayPositionChanged(Offset position) {
    _androidOverlayPosition = position;
    unawaited(_settings.setValue(SettingsKeys.androidOverlayX, position.dx));
    unawaited(_settings.setValue(SettingsKeys.androidOverlayY, position.dy));
  }

  /// 开关 Android 悬浮窗触摸穿透并持久化。
  Future<void> setAndroidTouchPassthroughEnabled(bool value) async {
    if (_androidTouchPassthroughEnabled == value) return;
    _androidTouchPassthroughEnabled = value;
    notifyListeners();
    await _settings.setValue(
      SettingsKeys.androidOverlayTouchPassthrough,
      value,
    );
    await _androidDisplay?.setTouchPassthrough(value);
  }

  /// 开关 Android 悬浮窗边缘吸附并持久化。
  Future<void> setAndroidEdgeSnapEnabled(bool value) async {
    if (_androidEdgeSnapEnabled == value) return;
    _androidEdgeSnapEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.androidOverlayEdgeSnap, value);
    await _androidDisplay?.setEdgeSnap(value);
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

  /// 开关 OBS 浏览器源;本地服务启动失败(如端口被占用)返回 false
  /// 并不改变开关状态。
  Future<bool> setObsOverlayEnabled(bool value) async {
    if (_obsOverlayEnabled == value) return true;
    final ok = await _obsOverlay?.setEnabled(value) ?? false;
    if (!ok) return false;
    _obsOverlayEnabled = value;
    notifyListeners();
    await _settings.setValue(SettingsKeys.obsOverlayEnabled, value);
    if (value) {
      // 服务缓存样式独立于启用时机,启用后立即对齐当前样式。
      await _obsOverlay?.setStyle(resolvedOverlayStyle);
    }
    unawaited(_syncAppMenu());
    return true;
  }

  /// 应用菜单条目点击:执行与对应开关行等价的切换动作。
  void _onAppMenuToggle(AppMenuToggle toggle) {
    switch (toggle) {
      case AppMenuToggle.desktopOverlay:
        setDesktopOverlayEnabled(!_desktopOverlayEnabled);
      case AppMenuToggle.mousePassthrough:
        // 悬浮窗关闭时菜单条目已置灰,防御性忽略。
        if (_desktopOverlayEnabled) {
          setMousePassthroughEnabled(!_mousePassthroughEnabled);
        }
      case AppMenuToggle.menubarHeart:
        setMenubarEnabled(!_menubarEnabled);
      case AppMenuToggle.obsOverlay:
        // 启动失败(如端口被占用)时状态不变,由 [_syncAppMenu]
        // 推送实际状态,菜单勾选自动回弹。
        setObsOverlayEnabled(!_obsOverlayEnabled);
    }
  }

  /// 推送四个开关的勾选 / 可用状态到应用菜单(去重由实现方负责)。
  Future<void> _syncAppMenu() async {
    await _appMenu?.update(
      AppMenuStates(
        desktopOverlay: _desktopOverlayEnabled,
        mousePassthrough: _desktopOverlayEnabled && _mousePassthroughEnabled,
        mousePassthroughEnabled: _desktopOverlayEnabled,
        menubarHeart: _menubarEnabled,
        obsOverlay: _obsOverlayEnabled,
      ),
    );
  }

  /// 更新心形大小(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayHeartSize(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(heartSize: value.clamp(36.0, 96.0)),
    );
  }

  /// 更新心率数字字号。
  void setOverlayBpmFontSize(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(bpmFontSize: value.clamp(12.0, 36.0)),
    );
  }

  /// 更新心形与数字的间距。
  void setOverlayHeartTextGap(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(heartTextGap: value.clamp(0.0, 24.0)),
    );
  }

  /// 更新悬浮窗心率内容(心形 + 数字)整体不透明度。
  void setOverlayContentOpacity(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(contentOpacity: value.clamp(0.1, 1.0)),
    );
  }

  /// 更新悬浮窗背景板不透明度(0 = 无背景板)。
  void setOverlayBackgroundOpacity(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(backgroundOpacity: value.clamp(0.0, 1.0)),
    );
  }

  /// 更新悬浮窗背景板颜色并持久化。
  void setOverlayBackgroundColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(backgroundColor: color));
    persistOverlayStyle();
  }

  /// 更新文字颜色并持久化。
  void setOverlayBpmColor(Color color) {
    _applyOverlayStyle(_overlayStyle.copyWith(bpmColor: color));
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
      _overlayStyle.copyWith(backgroundWidth: value.clamp(100.0, 240.0)),
    );
  }

  /// 更新背景板高度(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayBackgroundHeight(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(backgroundHeight: value.clamp(120.0, 280.0)),
    );
  }

  /// 更新是否显示 “bpm” 标签并持久化。
  void setOverlayShowBpmLabel(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(showBpmLabel: value));
    persistOverlayStyle();
  }

  /// 更新数字字重并持久化。
  void setOverlayBpmWeight(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(bpmWeight: value.clamp(100.0, 900.0)),
    );
    persistOverlayStyle();
  }

  /// 更新数字字体族并持久化;null 表示跟随全局字体。
  void setOverlayBpmFontFamily(String? family) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(
        bpmFontFamily: family,
        clearBpmFontFamily: family == null,
      ),
    );
    persistOverlayStyle();
  }

  /// 开关心率折线图并持久化;开启时背景板过小会自动放大。
  void setOverlayShowChart(bool value) {
    var style = _overlayStyle.copyWith(showChart: value);
    if (value) {
      // 折线图需要额外高度与宽度,背景板过小时自动放大(仅一次,可再手动调整)。
      style = style.copyWith(
        backgroundWidth: style.backgroundWidth < 180
            ? 180
            : style.backgroundWidth,
        backgroundHeight: style.backgroundHeight < 240
            ? 240
            : style.backgroundHeight,
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
      _overlayStyle.copyWith(chartHeight: value.clamp(40.0, 160.0)),
    );
  }

  /// 更新折线图与内容的间距(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayChartSpacing(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(chartSpacing: value.clamp(0.0, 24.0)),
    );
  }

  /// 更新心形脉冲开关并持久化。
  void setOverlayHeartPulseEnabled(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(heartPulseEnabled: value));
    persistOverlayStyle();
  }

  /// 更新文字律动开关并持久化。
  void setOverlayBpmPulseEnabled(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(bpmPulseEnabled: value));
    persistOverlayStyle();
  }

  /// 开关心跳辉光并持久化(半径/透明度设置保留,重新打开即恢复)。
  void setOverlayGlowEnabled(bool value) {
    _applyOverlayStyle(_overlayStyle.copyWith(glowEnabled: value));
    persistOverlayStyle();
  }

  /// 更新辉光半径倍率(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayGlowRadius(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(glowRadius: value.clamp(0.0, 3.0)),
    );
  }

  /// 更新辉光透明度倍率(仅更新状态与推送,拖动结束由 [persistOverlayStyle] 落盘)。
  void setOverlayGlowOpacity(double value) {
    _applyOverlayStyle(
      _overlayStyle.copyWith(glowOpacity: value.clamp(0.0, 1.0)),
    );
  }

  /// 把扫描 / 连接异常转换为面向用户的提示。
  static String _describeError(Object error) {
    if (error is BleException) return error.message;
    final text = error.toString().trim();
    return text.isEmpty ? '蓝牙操作失败' : text;
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
    _pushOverlayStyle();
  }

  /// 把[实际生效的样式]推送到各显示端(字体已按全局设置补全)。
  void _pushOverlayStyle() {
    final effective = resolvedOverlayStyle;
    _desktopOverlay?.setStyle(effective);
    _androidDisplay?.setStyle(effective);
    _obsOverlay?.setStyle(effective);
  }

  /// 将当前样式持久化。
  Future<void> persistOverlayStyle() async {
    await _settings.setValue(
      SettingsKeys.overlayHeartSize,
      _overlayStyle.heartSize,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmFontSize,
      _overlayStyle.bpmFontSize,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmPosition,
      _overlayStyle.bpmPosition.name,
    );
    await _settings.setValue(
      SettingsKeys.overlayEcgStyle,
      _overlayStyle.ecgStyle.name,
    );
    await _settings.setValue(
      SettingsKeys.overlayHeartTextGap,
      _overlayStyle.heartTextGap,
    );
    await _settings.setValue(
      SettingsKeys.overlayContentOpacity,
      _overlayStyle.contentOpacity,
    );
    await _settings.setValue(
      SettingsKeys.overlayBackgroundOpacity,
      _overlayStyle.backgroundOpacity,
    );
    await _settings.setValue(
      SettingsKeys.overlayBackgroundColor,
      _overlayStyle.backgroundColor.toARGB32().toRadixString(16),
    );
    await _settings.setValue(
      SettingsKeys.overlayBackgroundWidth,
      _overlayStyle.backgroundWidth,
    );
    await _settings.setValue(
      SettingsKeys.overlayBackgroundHeight,
      _overlayStyle.backgroundHeight,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmColor,
      _overlayStyle.bpmColor.toARGB32().toRadixString(16),
    );
    await _settings.setValue(
      SettingsKeys.overlayHeartColor,
      _overlayStyle.heartColor.toARGB32().toRadixString(16),
    );
    await _settings.setValue(
      SettingsKeys.overlayEcgColor,
      _overlayStyle.ecgColor.toARGB32().toRadixString(16),
    );
    await _settings.setValue(
      SettingsKeys.overlayShowChart,
      _overlayStyle.showChart,
    );
    await _settings.setValue(
      SettingsKeys.overlayChartSeconds,
      _overlayStyle.chartSeconds,
    );
    await _settings.setValue(
      SettingsKeys.overlayChartLineColor,
      _overlayStyle.chartLineColor.toARGB32().toRadixString(16),
    );
    await _settings.setValue(
      SettingsKeys.overlayChartHeight,
      _overlayStyle.chartHeight,
    );
    await _settings.setValue(
      SettingsKeys.overlayChartSpacing,
      _overlayStyle.chartSpacing,
    );
    await _settings.setValue(
      SettingsKeys.overlayShowBpmLabel,
      _overlayStyle.showBpmLabel,
    );
    await _settings.setValue(
      SettingsKeys.overlayShowChart,
      _overlayStyle.showChart,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmWeight,
      _overlayStyle.bpmWeight,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmFontFamily,
      _overlayStyle.bpmFontFamily,
    );
    await _settings.setValue(
      SettingsKeys.overlayHeartPulseEnabled,
      _overlayStyle.heartPulseEnabled,
    );
    await _settings.setValue(
      SettingsKeys.overlayBpmPulseEnabled,
      _overlayStyle.bpmPulseEnabled,
    );
    await _settings.setValue(
      SettingsKeys.overlayGlowEnabled,
      _overlayStyle.glowEnabled,
    );
    await _settings.setValue(
      SettingsKeys.overlayGlowRadius,
      _overlayStyle.glowRadius,
    );
    await _settings.setValue(
      SettingsKeys.overlayGlowOpacity,
      _overlayStyle.glowOpacity,
    );
  }

  @override
  void dispose() {
    _readingsSub?.cancel();
    _connectionSub?.cancel();
    _devicesSub?.cancel();
    _scanningSub?.cancel();
    _errorsSub?.cancel();
    _modeSub?.cancel();
    _overlayPositionSub?.cancel();
    _appMenu?.setToggleHandler(null);
    _appMenu?.setRefreshHandler(null);
    super.dispose();
  }
}
