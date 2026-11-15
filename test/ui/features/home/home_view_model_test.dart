import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:pulse_sight/data/services/heart_rate_source.dart';
import 'package:pulse_sight/data/services/platform/android_display_service.dart';
import 'package:pulse_sight/data/services/platform/desktop_overlay_service.dart';
import 'package:pulse_sight/data/services/platform/macos_menubar_service.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';

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

  void _setStatus(HeartRateConnection status) {
    status = status;
    _connectionController.add(status);
  }

  @override
  void dispose() {
    _bpmController.close();
    _connectionController.close();
  }
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
      final vm = HomeViewModel(
        repository: repository,
        settings: settings,
      );
      await vm.init();

      expect(vm.supportsAndroidDisplay, isFalse);
      expect(vm.supportsDesktopOverlay, isFalse);
      expect(vm.supportsMenubar, isFalse);
      vm.dispose();
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
      expect(
        settings.store[SettingsKeys.desktopOverlayEnabled],
        isTrue,
      );

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
  });
}
