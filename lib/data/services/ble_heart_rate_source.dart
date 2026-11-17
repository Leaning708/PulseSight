import 'dart:async';

import '../../domain/models/heart_rate_connection.dart';
import '../../domain/models/heart_rate_device.dart';
import 'ble_heart_rate_transport.dart';
import 'heart_rate_device_scanner.dart';
import 'heart_rate_measurement.dart';
import 'heart_rate_source.dart';

/// 基于 BLE 心率广播的真实数据源。
///
/// 扫描附近设备并连接标准心率服务(0x180D),订阅测量特征值(0x2A37)
/// 获取实时 bpm;连接意外断开时按 [reconnectDelays] 自动重连,
/// 全部尝试失败后回到未连接状态并通过 [errors] 提示用户。
///
/// 连接状态机与具体蓝牙插件之间隔着 [BleHeartRateTransport],
/// 便于在无蓝牙硬件的环境中测试扫描、订阅与重连逻辑。
class BleHeartRateSource implements HeartRateSource, HeartRateDeviceScanner {
  /// 创建数据源。
  ///
  /// [scanTimeout] 为单次扫描时长;[reconnectDelays] 为连接断开后的
  /// 重连等待序列,长度即最大重连次数。
  BleHeartRateSource(
    this._transport, {
    this.scanTimeout = const Duration(seconds: 12),
    this.reconnectDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  final BleHeartRateTransport _transport;

  /// 单次扫描时长。
  final Duration scanTimeout;

  /// 断线重连等待序列,长度即最大重连次数。
  final List<Duration> reconnectDelays;

  final StreamController<int> _bpmController =
      StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connectionController =
      StreamController<HeartRateConnection>.broadcast();
  final StreamController<List<HeartRateDevice>> _scanController =
      StreamController<List<HeartRateDevice>>.broadcast();
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  StreamSubscription<List<HeartRateDevice>>? _scanSubscription;
  StreamSubscription<int>? _bpmSubscription;

  Timer? _scanTimer;
  Timer? _reconnectTimer;

  HeartRateConnection _status = HeartRateConnection.disconnected;
  HeartRateDevice? _device;
  int? _bpm;
  bool _isScanning = false;
  bool _manualDisconnect = false;
  bool _disposed = false;
  int _generation = 0;
  int _reconnectAttempt = 0;
  List<HeartRateDevice> _devices = const [];

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  HeartRateConnection get status => _status;

  @override
  int? get currentBpm => _bpm;

  @override
  Stream<List<HeartRateDevice>> get scanResults async* {
    if (_devices.isNotEmpty) yield _devices;
    yield* _scanController.stream;
  }

  @override
  Stream<bool> get scanningStream async* {
    yield _isScanning;
    yield* _scanningController.stream;
  }

  @override
  bool get isScanning => _isScanning;

  @override
  HeartRateDevice? get connectedDevice =>
      _status == HeartRateConnection.disconnected ? null : _device;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  Future<void> startScan() async {
    if (_disposed || _isScanning) return;
    _scanTimer?.cancel();
    _devices = const [];
    if (!_scanController.isClosed) {
      _scanController.add(const []);
    }
    _ensureScanSubscription();
    _setScanning(true);
    try {
      await _transport.startScan();
    } on Object {
      _setScanning(false);
      rethrow;
    }
    if (_disposed || !_isScanning) return;
    _scanTimer = Timer(scanTimeout, () => unawaited(stopScan()));
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (!_isScanning) return;
    _setScanning(false);
    try {
      await _transport.stopScan();
    } on Object {
      // 停止扫描失败不影响后续操作。
    }
  }

  @override
  Future<void> connectTo(HeartRateDevice device) async {
    if (_disposed) return;
    _generation++;
    _manualDisconnect = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await stopScan();
    await _closeConnection();
    _device = device;
    _bpm = null;
    _setStatus(HeartRateConnection.connecting);
    await _openConnection(_generation);
  }

  @override
  Future<void> connect() async {
    if (_status != HeartRateConnection.disconnected || _disposed) return;

    final completer = Completer<HeartRateDevice?>();
    final subscription = _scanController.stream.listen((devices) {
      if (completer.isCompleted) return;
      for (final device in devices) {
        if (device.advertisesHeartRate) {
          completer.complete(device);
          return;
        }
      }
    });

    try {
      await startScan();
    } on Object catch (error) {
      await subscription.cancel();
      _emitError(_describe(error));
      _setStatus(HeartRateConnection.disconnected);
      return;
    }

    final device = await completer.future.timeout(
      scanTimeout,
      onTimeout: () => null,
    );
    await subscription.cancel();
    await stopScan();

    if (device == null) {
      _emitError('未发现心率设备,请确认手环已开启「心率广播」并靠近本机');
      _setStatus(HeartRateConnection.disconnected);
      return;
    }
    await connectTo(device);
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    _manualDisconnect = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // 先释放设备链路,再等待扫描停止:避免平台侧 stopScan 卡住时断连指令
    // 一直发不出去,导致其他中心设备无法连接。
    final stopScanFuture = stopScan();
    await _closeConnection();
    _device = null;
    _bpm = null;
    _setStatus(HeartRateConnection.disconnected);
    await stopScanFuture;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _scanTimer?.cancel();
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _bpmSubscription?.cancel();
    _transport.dispose();
    _bpmController.close();
    _connectionController.close();
    _scanController.close();
    _scanningController.close();
    _errorController.close();
  }

  /// 建立连接并订阅心率通知,失败时按重连序列重试。
  Future<void> _openConnection(int generation) async {
    final device = _device;
    if (device == null || _disposed || generation != _generation) return;
    try {
      final stream = await _transport.connect(device);
      if (_disposed || generation != _generation) {
        await _transport.disconnect();
        return;
      }
      _bpmSubscription = stream.listen(
        _onBpm,
        onError: (Object error, StackTrace _) =>
            _onConnectionLost(generation, error),
        onDone: () => _onConnectionLost(generation, null),
        cancelOnError: true,
      );
      _setStatus(HeartRateConnection.connected);
    } on Object catch (error) {
      _onConnectionLost(generation, error);
    }
  }

  void _onBpm(int bpm) {
    if (_disposed || !isValidHeartRate(bpm)) return;
    _bpm = bpm;
    if (_status != HeartRateConnection.connected) {
      _setStatus(HeartRateConnection.connected);
    }
    if (!_bpmController.isClosed) {
      _bpmController.add(bpm);
    }
  }

  /// 连接断开或建立失败:按配置重试,全部失败后提示并回到未连接。
  void _onConnectionLost(int generation, Object? error) {
    if (_disposed || generation != _generation) return;
    _bpmSubscription?.cancel();
    _bpmSubscription = null;
    _bpm = null;

    if (_manualDisconnect) {
      _setStatus(HeartRateConnection.disconnected);
      return;
    }

    if (_reconnectAttempt < reconnectDelays.length) {
      final delay = reconnectDelays[_reconnectAttempt];
      _reconnectAttempt++;
      _setStatus(HeartRateConnection.connecting);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        unawaited(_openConnection(generation));
      });
      return;
    }

    _device = null;
    _setStatus(HeartRateConnection.disconnected);
    _emitError(error == null ? '设备连接已断开,请确认手环已开启「心率广播」并在附近' : _describe(error));
  }

  Future<void> _closeConnection() async {
    final subscription = _bpmSubscription;
    _bpmSubscription = null;
    await subscription?.cancel();
    try {
      await _transport.disconnect();
    } on Object {
      // 设备可能已自行断开,忽略清理失败。
    }
  }

  void _ensureScanSubscription() {
    _scanSubscription ??= _transport.scanResults.listen((devices) {
      _devices = devices;
      if (!_scanController.isClosed) {
        _scanController.add(devices);
      }
    }, onError: (Object error, StackTrace _) => _emitError(_describe(error)));
  }

  void _setStatus(HeartRateConnection status) {
    if (_status == status) return;
    _status = status;
    if (!_connectionController.isClosed) {
      _connectionController.add(status);
    }
  }

  void _setScanning(bool scanning) {
    if (_isScanning == scanning) return;
    _isScanning = scanning;
    if (!_scanningController.isClosed) {
      _scanningController.add(scanning);
    }
  }

  void _emitError(String message) {
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  String _describe(Object error) {
    if (error is BleException) return error.message;
    if (error is TimeoutException) {
      return '连接超时,请确认手环已开启「心率广播」并靠近本机';
    }
    return '蓝牙连接失败:$error';
  }
}
