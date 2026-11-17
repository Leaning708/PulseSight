import 'dart:async';

import '../../domain/models/heart_rate_connection.dart';
import '../../domain/models/heart_rate_device.dart';
import '../../domain/models/heart_rate_mode.dart';
import '../../domain/models/heart_rate_scenario.dart';
import 'heart_rate_device_scanner.dart';
import 'heart_rate_mode_source.dart';
import 'heart_rate_scenario_source.dart';
import 'heart_rate_source.dart';
import 'real_heart_rate_source.dart';
import 'simulated_heart_rate_source.dart';

/// 可切换数据源:在真实 BLE 设备与模拟心率之间二选一。
///
/// 两种模式严格互斥:切换时先取消旧数据源的事件转发并调用其
/// `disconnect()`,再启用新数据源。对上层 Repository / UI 暴露为
/// 同一个 [HeartRateSource],因此切换模式不会重建 ViewModel。
class SwitchableHeartRateSource
    implements
        HeartRateSource,
        HeartRateDeviceScanner,
        HeartRateScenarioSource,
        HeartRateModeSource {
  /// 创建可切换数据源。
  SwitchableHeartRateSource({
    required this.real,
    required this.simulated,
    this.mode = HeartRateMode.real,
  }) {
    _attach();
  }

  /// 真实 BLE 数据源。
  final RealHeartRateSource real;

  /// 模拟心率数据源。
  final SimulatedHeartRateSource simulated;

  final StreamController<int> _bpmController =
      StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connectionController =
      StreamController<HeartRateConnection>.broadcast();
  final StreamController<HeartRateMode> _modeController =
      StreamController<HeartRateMode>.broadcast();

  StreamSubscription<int>? _bpmSubscription;
  StreamSubscription<HeartRateConnection>? _connectionSubscription;

  /// 上一次切换遗留的断开操作;真实模式重新连接前需等待其完成。
  Future<void> _pendingDisconnect = Future<void>.value();

  /// 当前模式。
  @override
  HeartRateMode mode;

  bool _disposed = false;

  HeartRateSource get _active => mode == HeartRateMode.real ? real : simulated;

  @override
  Stream<HeartRateMode> get modeStream async* {
    yield mode;
    yield* _modeController.stream;
  }

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  HeartRateConnection get status => _active.status;

  @override
  int? get currentBpm => _active.currentBpm;

  @override
  Future<void> connect() async {
    if (mode == HeartRateMode.real) await _pendingDisconnect;
    await _active.connect();
  }

  @override
  Future<void> disconnect() async {
    // 防御性同时断开两个数据源,确保不会出现两路同时产数据。
    await real.disconnect();
    await simulated.disconnect();
  }

  @override
  Future<void> setMode(HeartRateMode mode) async {
    if (_disposed || mode == this.mode) return;
    // 先同步摘除旧源的事件转发,再异步断开物理链路;新源不会收到旧源数据。
    _detach();
    final disconnects = <Future<void>>[
      real.disconnect().catchError((Object _) {}),
      simulated.disconnect().catchError((Object _) {}),
    ];
    _pendingDisconnect = Future.wait(disconnects);
    this.mode = mode;
    _attach();
    if (!_modeController.isClosed) {
      _modeController.add(mode);
    }
    // 切换后主动推送一次状态,保证 UI 立刻回到「未连接」。
    if (!_connectionController.isClosed) {
      _connectionController.add(_active.status);
    }
  }

  @override
  Stream<List<HeartRateDevice>> get scanResults => real.scanResults;

  @override
  Stream<bool> get scanningStream => real.scanningStream;

  @override
  bool get isScanning => real.isScanning;

  @override
  HeartRateDevice? get connectedDevice =>
      mode == HeartRateMode.real ? real.connectedDevice : null;

  @override
  Stream<String> get errors => real.errors;

  @override
  Future<void> startScan() async {
    // 模拟模式下不扫描,避免后台同时占用蓝牙。
    if (mode != HeartRateMode.real) return;
    await _pendingDisconnect;
    await real.startScan();
  }

  @override
  Future<void> stopScan() => real.stopScan();

  @override
  Future<void> connectTo(HeartRateDevice device) async {
    if (mode != HeartRateMode.real) return;
    await _pendingDisconnect;
    await real.connectTo(device);
  }

  @override
  HeartRateScenario get scenario => simulated.scenario;

  @override
  void setScenario(HeartRateScenario scenario) {
    simulated.setScenario(scenario);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bpmSubscription?.cancel();
    _connectionSubscription?.cancel();
    real.dispose();
    simulated.dispose();
    _bpmController.close();
    _connectionController.close();
    _modeController.close();
  }

  void _attach() {
    _bpmSubscription = _active.bpmStream.listen((bpm) {
      if (!_bpmController.isClosed) _bpmController.add(bpm);
    });
    _connectionSubscription = _active.connectionStream.listen((status) {
      if (!_connectionController.isClosed) {
        _connectionController.add(status);
      }
    });
  }

  void _detach() {
    _bpmSubscription?.cancel();
    _bpmSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }
}
