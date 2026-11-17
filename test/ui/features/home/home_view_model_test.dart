import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:pulse_sight/data/services/ble_heart_rate_transport.dart';
import 'package:pulse_sight/data/services/heart_rate_device_scanner.dart';
import 'package:pulse_sight/data/services/simulated_heart_rate_source.dart';
import 'package:pulse_sight/data/services/switchable_heart_rate_source.dart';
import 'package:pulse_sight/data/services/heart_rate_scenario_source.dart';
import 'package:pulse_sight/data/services/heart_rate_source.dart';
import 'package:pulse_sight/data/services/platform/android_display_service.dart';
import 'package:pulse_sight/data/services/platform/desktop_overlay_service.dart';
import 'package:pulse_sight/data/services/platform/font_list_service.dart';
import 'package:pulse_sight/data/services/platform/macos_app_menu_service.dart';
import 'package:pulse_sight/data/services/platform/macos_menubar_service.dart';
import 'package:pulse_sight/data/services/platform/obs_overlay_service.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/heart_rate_device.dart';
import 'package:pulse_sight/domain/models/heart_rate_mode.dart';
import 'package:pulse_sight/domain/models/heart_rate_scenario.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';

import '../../../data/services/real_heart_rate_source_fake.dart';

/// 手动控制状态与数据的心率源 Fake。
class FakeHeartRateSource implements HeartRateSource {
  final StreamController<int> _bpmController =
      StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connectionController =
      StreamController<HeartRateConnection>.broadcast();

  @override
  HeartRateConnection status = HeartRateConnection.disconnected;

  @override
  int? currentBpm;

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  void emitReading(int bpm) {
    currentBpm = bpm;
    _bpmController.add(bpm);
  }

  @override
  Future<void> connect() async {
    _setStatus(HeartRateConnection.connecting);
    _setStatus(HeartRateConnection.connected);
    emitReading(75);
  }

  @override
  Future<void> disconnect() async {
    currentBpm = null;
    _setStatus(HeartRateConnection.disconnected);
  }

  void _setStatus(HeartRateConnection next) {
    status = next;
    _connectionController.add(next);
  }

  @override
  void dispose() {
    _bpmController.close();
    _connectionController.close();
  }
}

/// 在 [FakeHeartRateSource] 之上追加设备扫描 / 指定连接能力的 Fake。
class FakeScannerHeartRateSource extends FakeHeartRateSource
    implements HeartRateDeviceScanner {
  final StreamController<List<HeartRateDevice>> _scanController =
      StreamController<List<HeartRateDevice>>.broadcast();
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  final List<String> calls = [];

  HeartRateDevice? targetDevice;

  bool scanning = false;

  /// startScan 抛出该异常(模拟蓝牙未开启)。
  Object? startScanError;

  @override
  Stream<List<HeartRateDevice>> get scanResults => _scanController.stream;

  @override
  Stream<bool> get scanningStream async* {
    yield scanning;
    yield* _scanningController.stream;
  }

  @override
  bool get isScanning => scanning;

  @override
  HeartRateDevice? get connectedDevice =>
      status == HeartRateConnection.connected ? targetDevice : null;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  Future<void> startScan() async {
    calls.add('startScan');
    final error = startScanError;
    if (error != null) throw error;
    _setScanning(true);
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
    _setScanning(false);
  }

  @override
  Future<void> connectTo(HeartRateDevice device) async {
    targetDevice = device;
    calls.add('connectTo:${device.id}');
    _setStatus(HeartRateConnection.connected);
    emitReading(72);
  }

  void emitDevices(List<HeartRateDevice> devices) {
    _scanController.add(devices);
  }

  void emitError(String message) {
    _errorController.add(message);
  }

  void _setScanning(bool value) {
    scanning = value;
    _scanningController.add(value);
  }

  @override
  void dispose() {
    _scanController.close();
    _scanningController.close();
    _errorController.close();
    super.dispose();
  }
}

/// 在 [FakeHeartRateSource] 之上追加模拟场景能力的 Fake。
class FakeScenarioHeartRateSource extends FakeHeartRateSource
    implements HeartRateScenarioSource {
  final List<HeartRateScenario> setCalls = [];

  @override
  HeartRateScenario scenario = HeartRateScenario.medium;

  @override
  void setScenario(HeartRateScenario scenario) {
    setCalls.add(scenario);
    this.scenario = scenario;
  }
}

/// OBS 浏览器源 Fake:记录调用,可配置启用结果。
class FakeObsOverlayDisplay implements ObsOverlayDisplay {
  final List<String> calls = [];

  /// setEnabled 的返回值;false 模拟端口被占用等启动失败。
  bool setEnabledResult = true;

  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add('setEnabled($enabled)');
    return setEnabledResult;
  }

  @override
  String get overlayUrl => 'http://127.0.0.1:9423/';

  @override
  Future<void> setStyle(OverlayStyle style) async {
    calls.add('style(${style.heartSize})');
  }

  @override
  void dispose() {}
}

/// 内存版设置仓库 Fake。
class FakeSettingsRepository implements SettingsRepository {
  final Map<String, Object?> store = {};

  @override
  Future<Map<String, Object?>> loadAll() async => Map.of(store);

  @override
  Future<void> setValue(String key, Object? value) async {
    store[key] = value;
  }
}

class FakeDesktopOverlay implements DesktopOverlay {
  final List<String> calls = [];

  @override
  Future<void> show({required bool passthrough}) async {
    calls.add('show($passthrough)');
  }

  @override
  Future<void> hide() async {
    calls.add('hide');
  }

  @override
  Future<void> setPassthrough(bool value) async {
    calls.add('passthrough($value)');
  }

  @override
  Future<void> setStyle(OverlayStyle style) async {
    calls.add('style(${style.heartSize}/${style.bpmPosition.name})');
  }

  @override
  void dispose() {}
}

class FakeMenubarDisplay implements MenubarDisplay {
  final List<String> calls = [];

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add('menubar($enabled)');
  }

  @override
  void dispose() {}
}

/// 应用菜单 Fake:记录推送状态,保存点击 / 刷新回调供模拟菜单操作。
class FakeAppMenuDisplay implements AppMenuDisplay {
  AppMenuStates? lastStates;

  int updateCount = 0;

  void Function(AppMenuToggle)? handler;

  void Function()? refreshHandler;

  @override
  Future<void> update(AppMenuStates states) async {
    updateCount++;
    lastStates = states;
  }

  @override
  void setToggleHandler(void Function(AppMenuToggle)? handler) {
    this.handler = handler;
  }

  @override
  void setRefreshHandler(void Function()? handler) {
    refreshHandler = handler;
  }

  /// 模拟用户点击菜单条目。
  void tap(AppMenuToggle toggle) => handler?.call(toggle);

  /// 模拟原生菜单重建时请求刷新状态。
  void refresh() => refreshHandler?.call();

  @override
  void dispose() {}
}

class FakeAndroidDisplay implements AndroidDisplay {
  final List<String> calls = [];
  bool overlayPermissionGranted = false;
  bool notificationPermissionGranted = false;

  @override
  Future<bool> ensureOverlayPermission() async {
    calls.add('ensureOverlayPermission');
    return overlayPermissionGranted;
  }

  @override
  Future<void> showOverlay() async {
    calls.add('showOverlay');
  }

  @override
  Future<void> hideOverlay() async {
    calls.add('hideOverlay');
  }

  @override
  Future<bool> setStatusBarEnabled(bool enabled) async {
    calls.add('statusBar($enabled)');
    if (enabled) {
      if (!notificationPermissionGranted) return false;
      return true;
    }
    return true;
  }

  @override
  Future<void> setStyle(OverlayStyle style) async {
    calls.add('style(${style.heartSize}/${style.ecgStyle.name})');
  }

  @override
  void dispose() {}
}

void main() {
  group('HomeViewModel', () {
    late FakeHeartRateSource source;
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late FakeDesktopOverlay desktopOverlay;
    late FakeMenubarDisplay menubar;
    late FakeAndroidDisplay androidDisplay;
    late HomeViewModel viewModel;

    setUp(() {
      source = FakeHeartRateSource();
      repository = HeartRateRepository(source: source);
      settings = FakeSettingsRepository();
      desktopOverlay = FakeDesktopOverlay();
      menubar = FakeMenubarDisplay();
      androidDisplay = FakeAndroidDisplay();
      viewModel = HomeViewModel(
        repository: repository,
        settings: settings,
        desktopOverlay: desktopOverlay,
        menubar: menubar,
        androidDisplay: androidDisplay,
      );
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('init 默认加载各开关状态(菜单栏默认开启)', () async {
      await viewModel.init();

      expect(viewModel.desktopOverlayEnabled, isFalse);
      expect(viewModel.mousePassthroughEnabled, isFalse);
      expect(viewModel.menubarEnabled, isTrue, reason: '菜单栏心率默认显示');
      expect(viewModel.androidOverlayEnabled, isFalse);
      expect(viewModel.statusBarEnabled, isFalse);
      expect(viewModel.canConnect, isTrue);
    });

    test('未注入 AndroidDisplay 时不支持 Android 显示端', () async {
      final vm = HomeViewModel(repository: repository, settings: settings);
      await vm.init();

      expect(vm.supportsAndroidDisplay, isFalse);
      expect(vm.supportsDesktopOverlay, isFalse);
      expect(vm.supportsMenubar, isFalse);
      vm.dispose();
    });

    test('未注入桌面悬浮窗服务时开关为空操作且不写持久化', () async {
      final vm = HomeViewModel(repository: repository, settings: settings);
      await vm.init();
      addTearDown(vm.dispose);

      expect(vm.supportsDesktopOverlay, isFalse);
      await vm.setDesktopOverlayEnabled(true);
      expect(vm.desktopOverlayEnabled, isFalse);
      expect(
        settings.store.containsKey(SettingsKeys.desktopOverlayEnabled),
        isFalse,
      );
    });

    test('init 后注入的服务暴露对应平台能力', () async {
      await viewModel.init();

      expect(viewModel.supportsDesktopOverlay, isTrue);
      expect(viewModel.supportsMenubar, isTrue);
      expect(viewModel.supportsAndroidDisplay, isTrue);
    });

    test('init 恢复桌面悬浮窗与菜单栏(Android 悬浮窗除外)', () async {
      settings.store
        ..[SettingsKeys.desktopOverlayEnabled] = true
        ..[SettingsKeys.mousePassthroughEnabled] = true
        ..[SettingsKeys.menubarEnabled] = true;

      await viewModel.init();

      expect(desktopOverlay.calls, contains('show(true)'));
      expect(menubar.calls, contains('menubar(true)'));
      expect(viewModel.desktopOverlayEnabled, isTrue);
      expect(viewModel.mousePassthroughEnabled, isTrue);
    });

    test('connect 后状态与 bpm 同步更新', () async {
      await viewModel.init();

      await viewModel.connect();
      await pumpEventQueue();

      expect(viewModel.connection, HeartRateConnection.connected);
      expect(viewModel.bpm, 75);
      expect(viewModel.canConnect, isFalse);
    });

    test('开关桌面悬浮窗调用服务并持久化', () async {
      await viewModel.init();

      await viewModel.setDesktopOverlayEnabled(true);

      expect(desktopOverlay.calls, contains('show(false)'));
      expect(settings.store[SettingsKeys.desktopOverlayEnabled], isTrue);

      await viewModel.setDesktopOverlayEnabled(false);

      expect(desktopOverlay.calls, contains('hide'));
      expect(settings.store[SettingsKeys.desktopOverlayEnabled], isFalse);
    });

    test('开关鼠标穿透调用服务并持久化', () async {
      await viewModel.init();
      await viewModel.setDesktopOverlayEnabled(true);

      await viewModel.setMousePassthroughEnabled(true);

      expect(desktopOverlay.calls, contains('passthrough(true)'));
      expect(settings.store[SettingsKeys.mousePassthroughEnabled], isTrue);
    });

    test('开关菜单栏调用服务并持久化', () async {
      await viewModel.init(); // 菜单栏默认开启
      menubar.calls.clear();

      await viewModel.setMenubarEnabled(false);

      expect(menubar.calls, contains('menubar(false)'));
      expect(settings.store[SettingsKeys.menubarEnabled], isFalse);

      await viewModel.setMenubarEnabled(true);

      expect(menubar.calls, contains('menubar(true)'));
      expect(settings.store[SettingsKeys.menubarEnabled], isTrue);
    });

    test('悬浮窗权限未授予时开关保持关闭', () async {
      androidDisplay.overlayPermissionGranted = false;
      await viewModel.init();

      final ok = await viewModel.setAndroidOverlayEnabled(true);

      expect(ok, isFalse);
      expect(viewModel.androidOverlayEnabled, isFalse);
      expect(
        settings.store.containsKey(SettingsKeys.androidOverlayEnabled),
        isFalse,
      );
    });

    test('悬浮窗权限授予后打开悬浮窗并持久化', () async {
      androidDisplay.overlayPermissionGranted = true;
      await viewModel.init();

      final ok = await viewModel.setAndroidOverlayEnabled(true);

      expect(ok, isTrue);
      expect(androidDisplay.calls, contains('showOverlay'));
      expect(viewModel.androidOverlayEnabled, isTrue);
      expect(settings.store[SettingsKeys.androidOverlayEnabled], isTrue);
    });

    test('通知权限未授予时状态栏开关失败', () async {
      androidDisplay.notificationPermissionGranted = false;
      await viewModel.init();

      final ok = await viewModel.setStatusBarEnabled(true);

      expect(ok, isFalse);
      expect(viewModel.statusBarEnabled, isFalse);
    });

    test('断开连接后心率清空', () async {
      await viewModel.init();
      await viewModel.connect();
      await pumpEventQueue();

      await viewModel.disconnect();
      await pumpEventQueue();

      expect(viewModel.connection, HeartRateConnection.disconnected);
      expect(viewModel.canConnect, isTrue);
      expect(viewModel.bpm, isNull);
    });

    test('调节悬浮窗样式:更新状态并推送到显示端', () async {
      await viewModel.init();

      viewModel.setOverlayHeartSize(80);
      expect(viewModel.overlayStyle.heartSize, 80);
      expect(desktopOverlay.calls, contains('style(80.0/bottom)'));

      viewModel.setOverlayEcgStyle(EcgStyle.single);
      expect(viewModel.overlayStyle.ecgStyle, EcgStyle.single);
      expect(androidDisplay.calls, contains('style(80.0/single)'));

      viewModel.setOverlayBpmPosition(BpmPosition.left);
      expect(viewModel.overlayStyle.bpmPosition, BpmPosition.left);
    });

    test('persistOverlayStyle 将全部样式字段落盘', () async {
      await viewModel.init();
      viewModel
        ..setOverlayHeartSize(90)
        ..setOverlayBpmFontSize(30)
        ..setOverlayBpmPosition(BpmPosition.top)
        ..setOverlayEcgStyle(EcgStyle.flat)
        ..setOverlayGap(12);

      await viewModel.persistOverlayStyle();

      expect(settings.store[SettingsKeys.overlayHeartSize], 90.0);
      expect(settings.store[SettingsKeys.overlayBpmFontSize], 30.0);
      expect(settings.store[SettingsKeys.overlayBpmPosition], 'top');
      expect(settings.store[SettingsKeys.overlayEcgStyle], 'flat');
      expect(settings.store[SettingsKeys.overlayGap], 12.0);
    });

    test('init 恢复持久化的悬浮窗样式', () async {
      settings.store
        ..[SettingsKeys.overlayHeartSize] = 88.0
        ..[SettingsKeys.overlayBpmFontSize] = 28.0
        ..[SettingsKeys.overlayBpmPosition] = 'right'
        ..[SettingsKeys.overlayEcgStyle] = 'none'
        ..[SettingsKeys.overlayGap] = 10.0;

      await viewModel.init();

      expect(viewModel.overlayStyle.heartSize, 88);
      expect(viewModel.overlayStyle.bpmFontSize, 28);
      expect(viewModel.overlayStyle.bpmPosition, BpmPosition.right);
      expect(viewModel.overlayStyle.ecgStyle, EcgStyle.none);
      expect(viewModel.overlayStyle.gap, 10);
    });

    test('init 加载系统字体列表并暴露给字体下拉', () async {
      final fontList = FontListService(
        loader: () async => ['Microsoft YaHei', 'Arial'],
      );
      final vm = HomeViewModel(
        repository: repository,
        settings: settings,
        fontListService: fontList,
      );

      await vm.init();
      await fontList.ready;

      expect(vm.overlayFontFamilies, ['Arial', 'Microsoft YaHei']);
      vm.dispose();
    });

    test('选择字体后可切回默认(系统)', () async {
      await viewModel.init();

      viewModel.setOverlayTextFontFamily('Microsoft YaHei');
      expect(viewModel.overlayStyle.textFontFamily, 'Microsoft YaHei');

      viewModel.setOverlayTextFontFamily(null);
      await pumpEventQueue();
      expect(viewModel.overlayStyle.textFontFamily, isNull);
      expect(
        settings.store[SettingsKeys.overlayTextFontFamily],
        isNull,
        reason: '切回系统默认后持久化值应被移除',
      );
    });
  });

  group('模拟场景', () {
    late FakeScenarioHeartRateSource scenarioSource;
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late HomeViewModel viewModel;

    setUp(() {
      scenarioSource = FakeScenarioHeartRateSource();
      repository = HeartRateRepository(source: scenarioSource);
      settings = FakeSettingsRepository();
      viewModel = HomeViewModel(repository: repository, settings: settings);
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('init 读取数据源当前场景并暴露能力位', () async {
      scenarioSource.scenario = HeartRateScenario.low;
      await viewModel.init();

      expect(viewModel.supportsScenario, isTrue);
      expect(viewModel.scenario, HeartRateScenario.low);
    });

    test('setScenario 转发数据源、更新状态并持久化', () async {
      await viewModel.init();

      await viewModel.setScenario(HeartRateScenario.high);

      expect(scenarioSource.setCalls, [HeartRateScenario.high]);
      expect(viewModel.scenario, HeartRateScenario.high);
      expect(settings.store[SettingsKeys.simulatedScenario], 'high');
    });

    test('重复设置相同场景不产生转发与持久化', () async {
      await viewModel.init(); // 默认 medium

      await viewModel.setScenario(HeartRateScenario.medium);

      expect(scenarioSource.setCalls, isEmpty);
      expect(
        settings.store.containsKey(SettingsKeys.simulatedScenario),
        isFalse,
      );
    });

    test('数据源不支持场景时能力为 false 且切换为空操作', () async {
      final source = FakeHeartRateSource();
      final repo = HeartRateRepository(source: source);
      final vm = HomeViewModel(repository: repo, settings: settings);
      await vm.init();

      expect(vm.supportsScenario, isFalse);
      expect(vm.scenario, HeartRateScenario.medium);

      await vm.setScenario(HeartRateScenario.high);

      expect(vm.scenario, HeartRateScenario.medium);
      expect(
        settings.store.containsKey(SettingsKeys.simulatedScenario),
        isFalse,
      );
      vm.dispose();
      repo.dispose();
    });
  });

  group('OBS 浏览器源', () {
    late FakeObsOverlayDisplay obsOverlay;
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late HomeViewModel viewModel;

    setUp(() {
      obsOverlay = FakeObsOverlayDisplay();
      repository = HeartRateRepository(source: FakeHeartRateSource());
      settings = FakeSettingsRepository();
      viewModel = HomeViewModel(
        repository: repository,
        settings: settings,
        obsOverlay: obsOverlay,
      );
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('注入服务时暴露能力位与地址', () async {
      await viewModel.init();

      expect(viewModel.supportsObsOverlay, isTrue);
      expect(viewModel.obsOverlayUrl, 'http://127.0.0.1:9423/');
      expect(viewModel.obsOverlayEnabled, isFalse);
    });

    test('开启开关调用服务并持久化,样式随之对齐', () async {
      await viewModel.init();

      final ok = await viewModel.setObsOverlayEnabled(true);

      expect(ok, isTrue);
      expect(obsOverlay.calls, contains('setEnabled(true)'));
      expect(obsOverlay.calls, contains('style(64.0)'));
      expect(viewModel.obsOverlayEnabled, isTrue);
      expect(settings.store[SettingsKeys.obsOverlayEnabled], isTrue);
    });

    test('重复开关同一状态为空操作', () async {
      await viewModel.init();
      await viewModel.setObsOverlayEnabled(true);
      obsOverlay.calls.clear();

      final ok = await viewModel.setObsOverlayEnabled(true);

      expect(ok, isTrue);
      expect(obsOverlay.calls, isEmpty);
    });

    test('启动失败返回 false 且不持久化', () async {
      await viewModel.init();
      obsOverlay.setEnabledResult = false;

      final ok = await viewModel.setObsOverlayEnabled(true);

      expect(ok, isFalse);
      expect(viewModel.obsOverlayEnabled, isFalse);
      expect(
        settings.store.containsKey(SettingsKeys.obsOverlayEnabled),
        isFalse,
      );
    });

    test('init 恢复持久化的开启状态并对齐样式', () async {
      settings.store[SettingsKeys.obsOverlayEnabled] = true;

      await viewModel.init();

      expect(viewModel.obsOverlayEnabled, isTrue);
      expect(obsOverlay.calls, contains('setEnabled(true)'));
      expect(obsOverlay.calls, contains('style(64.0)'));
    });

    test('init 时启动失败回落为关闭', () async {
      settings.store[SettingsKeys.obsOverlayEnabled] = true;
      obsOverlay.setEnabledResult = false;

      await viewModel.init();

      expect(viewModel.obsOverlayEnabled, isFalse);
    });

    test('未注入服务时能力位为 false 且开关为空操作', () async {
      final vm = HomeViewModel(repository: repository, settings: settings);
      await vm.init();

      expect(vm.supportsObsOverlay, isFalse);
      expect(vm.obsOverlayUrl, isEmpty);
      expect(await vm.setObsOverlayEnabled(true), isFalse);

      vm.dispose();
    });
  });

  group('应用菜单', () {
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late FakeDesktopOverlay desktopOverlay;
    late FakeAppMenuDisplay appMenu;
    late HomeViewModel viewModel;

    setUp(() {
      repository = HeartRateRepository(source: FakeHeartRateSource());
      settings = FakeSettingsRepository();
      desktopOverlay = FakeDesktopOverlay();
      appMenu = FakeAppMenuDisplay();
      viewModel = HomeViewModel(
        repository: repository,
        settings: settings,
        desktopOverlay: desktopOverlay,
        appMenu: appMenu,
        obsOverlay: FakeObsOverlayDisplay(),
      );
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('init 后注册回调并推送初始状态', () async {
      await viewModel.init();
      await pumpEventQueue();

      expect(appMenu.handler, isNotNull);
      expect(appMenu.updateCount, greaterThan(0));
      expect(
        appMenu.lastStates,
        const AppMenuStates(
          desktopOverlay: false,
          mousePassthrough: false,
          mousePassthroughEnabled: false,
          // 菜单栏心率默认开启。
          menubarHeart: true,
          obsOverlay: false,
        ),
      );
    });

    test('点击菜单条目切换桌面悬浮窗并推送新状态', () async {
      await viewModel.init();
      await pumpEventQueue();

      appMenu.tap(AppMenuToggle.desktopOverlay);
      await pumpEventQueue();

      expect(viewModel.desktopOverlayEnabled, isTrue);
      expect(desktopOverlay.calls, contains('show(false)'));
      expect(
        appMenu.lastStates,
        const AppMenuStates(
          desktopOverlay: true,
          mousePassthrough: false,
          mousePassthroughEnabled: true,
          menubarHeart: true,
          obsOverlay: false,
        ),
      );
    });

    test('悬浮窗关闭时菜单点击鼠标穿透被忽略', () async {
      await viewModel.init();
      await pumpEventQueue();

      appMenu.tap(AppMenuToggle.mousePassthrough);
      await pumpEventQueue();

      expect(viewModel.mousePassthroughEnabled, isFalse);
    });

    test('悬浮窗开启后菜单点击鼠标穿透生效且联动推送', () async {
      await viewModel.init();
      await pumpEventQueue();

      appMenu.tap(AppMenuToggle.desktopOverlay);
      await pumpEventQueue();
      appMenu.tap(AppMenuToggle.mousePassthrough);
      await pumpEventQueue();

      expect(viewModel.mousePassthroughEnabled, isTrue);
      expect(desktopOverlay.calls, contains('passthrough(true)'));
      expect(appMenu.lastStates?.mousePassthrough, isTrue);
      expect(appMenu.lastStates?.mousePassthroughEnabled, isTrue);
    });

    test('点击菜单条目切换菜单栏心率并推送', () async {
      await viewModel.init();
      await pumpEventQueue();

      appMenu.tap(AppMenuToggle.menubarHeart);
      await pumpEventQueue();

      expect(viewModel.menubarEnabled, isFalse);
      expect(appMenu.lastStates?.menubarHeart, isFalse);
    });

    test('点击菜单条目切换 OBS 并持久化', () async {
      await viewModel.init();
      await pumpEventQueue();

      appMenu.tap(AppMenuToggle.obsOverlay);
      await pumpEventQueue();

      expect(viewModel.obsOverlayEnabled, isTrue);
      expect(settings.store[SettingsKeys.obsOverlayEnabled], isTrue);
      expect(appMenu.lastStates?.obsOverlay, isTrue);
    });

    test('refresh 后按当前状态重新推送(菜单重建对齐)', () async {
      await viewModel.init();
      await pumpEventQueue();
      appMenu.tap(AppMenuToggle.desktopOverlay);
      await pumpEventQueue();
      final pushed = appMenu.updateCount;

      // 状态项菜单重建时,原生经 refresh 请求当前状态,须重复推送。
      appMenu.refresh();
      await pumpEventQueue();

      expect(appMenu.updateCount, greaterThan(pushed));
      expect(appMenu.lastStates?.desktopOverlay, isTrue);
    });
  });

  group('设备扫描', () {
    late FakeScannerHeartRateSource source;
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late HomeViewModel viewModel;

    const band = HeartRateDevice(
      id: 'band-1',
      name: 'Xiaomi Smart Band 10',
      rssi: -48,
      advertisesHeartRate: true,
    );
    const buds = HeartRateDevice(id: 'buds', name: 'AirPods', rssi: -70);

    setUp(() {
      source = FakeScannerHeartRateSource();
      repository = HeartRateRepository(source: source);
      settings = FakeSettingsRepository();
      viewModel = HomeViewModel(repository: repository, settings: settings);
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('扫描结果默认只保留心率设备,可切换显示全部', () async {
      await viewModel.init();
      expect(viewModel.supportsDevicePicker, isTrue);

      source.emitDevices([band, buds]);
      await pumpEventQueue();

      expect(viewModel.discoveredDevices.map((d) => d.id), ['band-1']);
      expect(viewModel.showAllDevices, isFalse);

      viewModel.setShowAllDevices(true);
      expect(viewModel.discoveredDevices.map((d) => d.id), ['band-1', 'buds']);
    });

    test('beginDeviceScan 开始扫描,stopDeviceScan 停止', () async {
      await viewModel.init();

      await viewModel.beginDeviceScan();

      expect(source.calls, contains('startScan'));
      expect(viewModel.isScanning, isTrue);

      await viewModel.stopDeviceScan();

      expect(viewModel.isScanning, isFalse);
      expect(source.calls, contains('stopScan'));
    });

    test('扫描失败显示错误并复位扫描状态', () async {
      source.startScanError = const BleException('蓝牙未开启或未授权');
      await viewModel.init();

      await viewModel.beginDeviceScan();

      expect(viewModel.scanError, '蓝牙未开启或未授权');
      expect(viewModel.isScanning, isFalse);
    });

    test('连接选中设备后同步设备名与心率', () async {
      await viewModel.init();

      await viewModel.connectToDevice(band);
      await pumpEventQueue();

      expect(source.calls, contains('connectTo:band-1'));
      expect(viewModel.connection, HeartRateConnection.connected);
      expect(viewModel.connectedDevice, band);
      expect(viewModel.bpm, 72);
    });

    test('连接成功后持久化设备 ID 与名称', () async {
      await viewModel.init();

      await viewModel.connectToDevice(band);
      await pumpEventQueue();

      expect(settings.store[SettingsKeys.bleLastDeviceId], 'band-1');
      expect(
        settings.store[SettingsKeys.bleLastDeviceName],
        'Xiaomi Smart Band 10',
      );
    });

    test('断开后扫描结果丢失名称 / 心率标记时仍保留上次设备', () async {
      await viewModel.init();
      await viewModel.connectToDevice(band);
      await pumpEventQueue();
      await viewModel.disconnect();
      await pumpEventQueue();

      // 手环断开后广播包不再携带名称与 0x180D 服务标记。
      source.emitDevices(const [
        HeartRateDevice(id: 'band-1', name: '', rssi: -46),
      ]);
      await pumpEventQueue();

      final devices = viewModel.discoveredDevices;
      expect(devices, hasLength(1));
      expect(devices.single.name, 'Xiaomi Smart Band 10');
      expect(devices.single.isRemembered, isTrue);
      expect(devices.single.advertisesHeartRate, isFalse);

      await viewModel.connectToDevice(devices.single);
      await pumpEventQueue();
      expect(source.calls, contains('connectTo:band-1'));
    });

    test('启动时恢复上次设备并在无扫描结果时仍可连接', () async {
      settings.store
        ..[SettingsKeys.bleLastDeviceId] = 'band-1'
        ..[SettingsKeys.bleLastDeviceName] = 'Xiaomi Smart Band 10';
      await viewModel.init();

      source.emitDevices(const []);
      await pumpEventQueue();

      final devices = viewModel.discoveredDevices;
      expect(devices, hasLength(1));
      expect(devices.single.id, 'band-1');
      expect(devices.single.isRemembered, isTrue);
    });

    test('连接错误写入 connectionError,断开后清空', () async {
      await viewModel.init();
      await viewModel.connectToDevice(band);
      await pumpEventQueue();

      source.emitError('设备连接已断开,请确认手环已开启「心率广播」');
      await pumpEventQueue();

      expect(viewModel.connectionError, contains('设备连接已断开'));

      await viewModel.disconnect();
      await pumpEventQueue();

      expect(viewModel.connectedDevice, isNull);
      expect(viewModel.connectionError, isNull);
    });
  });

  group('真实 / 模拟模式切换', () {
    late FakeRealHeartRateSource realSource;
    late SimulatedHeartRateSource simulatedSource;
    late SwitchableHeartRateSource source;
    late HeartRateRepository repository;
    late FakeSettingsRepository settings;
    late HomeViewModel viewModel;

    const band = HeartRateDevice(
      id: 'band-1',
      name: 'Xiaomi Smart Band 10',
      advertisesHeartRate: true,
    );

    setUp(() {
      realSource = FakeRealHeartRateSource();
      simulatedSource = SimulatedHeartRateSource(
        connectDelay: Duration.zero,
        sampleInterval: const Duration(hours: 1),
      );
      source = SwitchableHeartRateSource(
        real: realSource,
        simulated: simulatedSource,
      );
      repository = HeartRateRepository(source: source);
      settings = FakeSettingsRepository();
      viewModel = HomeViewModel(repository: repository, settings: settings);
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('初始为真实模式,场景 UI 隐藏且支持选设备', () async {
      await viewModel.init();

      expect(viewModel.supportsModeSwitch, isTrue);
      expect(viewModel.mode, HeartRateMode.real);
      expect(viewModel.isSimulatedMode, isFalse);
      expect(viewModel.supportsScenario, isFalse);
      expect(viewModel.supportsDevicePicker, isTrue);
    });

    test('切到模拟模式会断开真实设备并自动开始模拟', () async {
      await viewModel.init();
      await viewModel.connectToDevice(band);
      await pumpEventQueue();
      expect(viewModel.connection, HeartRateConnection.connected);

      await viewModel.setMode(HeartRateMode.simulated);
      await pumpEventQueue(times: 20);

      expect(realSource.calls, contains('disconnect'));
      expect(viewModel.mode, HeartRateMode.simulated);
      expect(viewModel.isSimulatedMode, isTrue);
      expect(viewModel.supportsScenario, isTrue);
      expect(viewModel.supportsDevicePicker, isFalse);
      expect(viewModel.connection, HeartRateConnection.connected);
      expect(viewModel.bpm, isNotNull);
      expect(settings.store[SettingsKeys.heartRateMode], 'simulated');
    });

    test('切回真实模式会断开模拟并清空数据', () async {
      await viewModel.init();
      await viewModel.setMode(HeartRateMode.simulated);
      await pumpEventQueue(times: 20);
      expect(viewModel.connection, HeartRateConnection.connected);

      await viewModel.setMode(HeartRateMode.real);
      await pumpEventQueue();

      expect(simulatedSource.status, HeartRateConnection.disconnected);
      expect(viewModel.mode, HeartRateMode.real);
      expect(viewModel.connection, HeartRateConnection.disconnected);
      expect(viewModel.connectedDevice, isNull);
      expect(viewModel.bpm, isNull);
      expect(viewModel.supportsScenario, isFalse);
      expect(settings.store[SettingsKeys.heartRateMode], 'real');
    });

    test('以模拟模式启动时自动连接', () async {
      final localSimulated = SimulatedHeartRateSource(
        connectDelay: Duration.zero,
        sampleInterval: const Duration(hours: 1),
      );
      final localReal = FakeRealHeartRateSource();
      final localSource = SwitchableHeartRateSource(
        real: localReal,
        simulated: localSimulated,
        mode: HeartRateMode.simulated,
      );
      final localRepository = HeartRateRepository(source: localSource);
      final localViewModel = HomeViewModel(
        repository: localRepository,
        settings: FakeSettingsRepository(),
      );

      await localViewModel.init();
      await pumpEventQueue(times: 20);

      expect(localViewModel.isSimulatedMode, isTrue);
      expect(localViewModel.connection, HeartRateConnection.connected);
      expect(localViewModel.bpm, isNotNull);

      localViewModel.dispose();
      localRepository.dispose();
    });

    test('模拟模式支持场景切换', () async {
      await viewModel.init();
      await viewModel.setMode(HeartRateMode.simulated);
      await pumpEventQueue(times: 20);

      await viewModel.setScenario(HeartRateScenario.high);

      expect(viewModel.scenario, HeartRateScenario.high);
      expect(simulatedSource.scenario, HeartRateScenario.high);
    });
  });
}
