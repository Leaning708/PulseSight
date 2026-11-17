import 'dart:async';

import 'package:pulse_sight/data/services/real_heart_rate_source.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/heart_rate_device.dart';

/// 可控的真实 BLE 数据源 Fake:提供心率流与扫描能力。
class FakeRealHeartRateSource implements RealHeartRateSource {
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

  final List<String> calls = [];

  @override
  HeartRateConnection status = HeartRateConnection.disconnected;

  HeartRateDevice? device;

  bool scanning = false;

  int? _bpm;

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  int? get currentBpm => _bpm;

  @override
  Stream<List<HeartRateDevice>> get scanResults => _scanController.stream;

  @override
  Stream<bool> get scanningStream => _scanningController.stream;

  @override
  bool get isScanning => scanning;

  @override
  HeartRateDevice? get connectedDevice =>
      status == HeartRateConnection.connected ? device : null;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  Future<void> connect() async {
    calls.add('connect');
    _setStatus(HeartRateConnection.connected);
  }

  @override
  Future<void> connectTo(HeartRateDevice device) async {
    this.device = device;
    calls.add('connectTo:${device.id}');
    _setStatus(HeartRateConnection.connected);
    emitBpm(80);
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    _bpm = null;
    _setStatus(HeartRateConnection.disconnected);
  }

  @override
  Future<void> startScan() async {
    calls.add('startScan');
    scanning = true;
    _scanningController.add(true);
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
    scanning = false;
    _scanningController.add(false);
  }

  @override
  void dispose() {
    _bpmController.close();
    _connectionController.close();
    _scanController.close();
    _scanningController.close();
    _errorController.close();
  }

  void emitBpm(int bpm) {
    _bpm = bpm;
    _bpmController.add(bpm);
  }

  void emitScanResults(List<HeartRateDevice> devices) {
    _scanController.add(devices);
  }

  void emitError(String message) => _errorController.add(message);

  void _setStatus(HeartRateConnection status) {
    this.status = status;
    _connectionController.add(status);
  }
}
