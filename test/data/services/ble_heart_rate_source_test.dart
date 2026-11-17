import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/ble_heart_rate_source.dart';
import 'package:pulse_sight/data/services/ble_heart_rate_transport.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/heart_rate_device.dart';

const _band = HeartRateDevice(
  id: 'band-1',
  name: 'Xiaomi Smart Band 10',
  rssi: -48,
  advertisesHeartRate: true,
);

/// 可控 BLE 传输层:记录调用,并按测试需要推送扫描结果 / 心率 / 断开。
class FakeBleTransport implements BleHeartRateTransport {
  final StreamController<List<HeartRateDevice>> _scanController =
      StreamController<List<HeartRateDevice>>.broadcast();

  StreamController<int>? _bpmController;

  final List<String> calls = [];

  /// startScan 抛出该异常(模拟蓝牙未开启)。
  Object? startScanError;

  /// connect 抛出该异常(模拟设备无心率服务 / 连接失败)。
  Object? connectError;

  /// startScan 时自动推送的扫描结果。
  List<HeartRateDevice> devicesOnStart = const [];

  int connectCount = 0;

  /// 非空时 stopScan 会等待该 Completer(模拟平台侧卡住)。
  Completer<void>? stopScanGate;

  bool disposed = false;

  @override
  Stream<List<HeartRateDevice>> get scanResults => _scanController.stream;

  @override
  Future<void> startScan() async {
    calls.add('startScan');
    final error = startScanError;
    if (error != null) throw error;
    if (devicesOnStart.isNotEmpty) {
      _scanController.add(devicesOnStart);
    }
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
    await stopScanGate?.future;
  }

  @override
  Future<Stream<int>> connect(HeartRateDevice device) async {
    connectCount++;
    calls.add('connect:${device.id}');
    final error = connectError;
    if (error != null) throw error;
    final controller = StreamController<int>.broadcast();
    _bpmController = controller;
    return controller.stream;
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    await _bpmController?.close();
    _bpmController = null;
  }

  /// 推送一次心率采样。
  void emitBpm(int bpm) {
    final controller = _bpmController;
    if (controller != null && !controller.isClosed) controller.add(bpm);
  }

  /// 推送一次扫描结果(模拟扫描过程中发现新设备)。
  void emitDevices(List<HeartRateDevice> devices) {
    devicesOnStart = devices;
    _scanController.add(devices);
  }

  /// 模拟设备侧断开(走出范围 / 关机)。
  void dropConnection() {
    final controller = _bpmController;
    _bpmController = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
  }

  @override
  void dispose() {
    disposed = true;
    _bpmController?.close();
    _scanController.close();
  }
}

void main() {
  late FakeBleTransport transport;
  late BleHeartRateSource source;
  late List<String> errors;

  setUp(() {
    transport = FakeBleTransport();
    source = BleHeartRateSource(
      transport,
      scanTimeout: const Duration(seconds: 5),
      reconnectDelays: const [],
    );
    errors = [];
    source.errors.listen(errors.add);
  });

  tearDown(() {
    source.dispose();
  });

  group('扫描', () {
    test('开始 / 停止扫描更新状态并调用传输层', () async {
      await source.startScan();

      expect(source.isScanning, isTrue);
      expect(transport.calls, contains('startScan'));

      await source.stopScan();

      expect(source.isScanning, isFalse);
      expect(transport.calls, contains('stopScan'));
    });

    test('扫描结果透过数据源暴露', () async {
      final results = <List<HeartRateDevice>>[];
      final sub = source.scanResults.listen(results.add);
      addTearDown(sub.cancel);

      await source.startScan();
      transport.emitDevices([
        _band,
        const HeartRateDevice(id: 'buds', name: 'AirPods'),
      ]);
      await pumpEventQueue();

      expect(results.last.map((device) => device.id), ['band-1', 'buds']);
    });

    test('蓝牙不可用时抛出并复位扫描状态', () async {
      transport.startScanError = const BleException('蓝牙未开启,请在系统设置中允许使用蓝牙');

      await expectLater(source.startScan(), throwsA(isA<BleException>()));

      expect(source.isScanning, isFalse);
    });
  });

  group('连接与采样', () {
    test('连接设备后进入已连接并按 bpm 推送采样', () async {
      final bpms = <int>[];
      final sub = source.bpmStream.listen(bpms.add);
      addTearDown(sub.cancel);

      await source.connectTo(_band);

      expect(source.status, HeartRateConnection.connected);
      expect(source.connectedDevice, _band);
      expect(transport.calls, contains('connect:band-1'));

      transport.emitBpm(72);
      await pumpEventQueue();

      expect(bpms, [72]);
      expect(source.currentBpm, 72);
    });

    test('未佩戴时的 0 与异常大值不进入采样流', () async {
      final bpms = <int>[];
      final sub = source.bpmStream.listen(bpms.add);
      addTearDown(sub.cancel);

      await source.connectTo(_band);
      transport.emitBpm(0);
      transport.emitBpm(400);
      await pumpEventQueue();

      expect(bpms, isEmpty);
      expect(source.currentBpm, isNull);
    });

    test('断开连接清空心率与设备', () async {
      await source.connectTo(_band);
      transport.emitBpm(72);
      await pumpEventQueue();

      await source.disconnect();

      expect(source.status, HeartRateConnection.disconnected);
      expect(source.currentBpm, isNull);
      expect(source.connectedDevice, isNull);
      expect(transport.calls, contains('disconnect'));
    });

    test('平台停止扫描卡住时仍会先断开设备', () async {
      await source.connectTo(_band);
      await source.startScan();
      transport.stopScanGate = Completer<void>();

      final disconnectFuture = source.disconnect();
      await pumpEventQueue();

      expect(transport.calls, contains('disconnect'));
      expect(source.status, HeartRateConnection.disconnected);

      transport.stopScanGate?.complete();
      await disconnectFuture;
    });

    test('连接失败通过 errors 通知并回到未连接', () async {
      transport.connectError = const BleException(
        '未找到心率测量服务(0x2A37),请确认设备已开启「心率广播」',
      );

      await source.connectTo(_band);
      await pumpEventQueue();

      expect(source.status, HeartRateConnection.disconnected);
      expect(errors, isNotEmpty);
      expect(errors.last, contains('心率测量服务'));
    });
  });

  group('断线重连', () {
    test('意外断开后自动重连并继续采样', () async {
      source.dispose();
      transport = FakeBleTransport();
      source = BleHeartRateSource(
        transport,
        scanTimeout: const Duration(seconds: 5),
        reconnectDelays: const [Duration.zero],
      );
      errors = [];
      source.errors.listen(errors.add);

      await source.connectTo(_band);
      expect(transport.connectCount, 1);

      transport.dropConnection();
      await pumpEventQueue(times: 20);

      expect(transport.connectCount, 2);
      expect(source.status, HeartRateConnection.connected);

      transport.emitBpm(88);
      await pumpEventQueue();
      expect(source.currentBpm, 88);
      expect(errors, isEmpty);
    });

    test('重连次数耗尽后提示并回到未连接', () async {
      source.dispose();
      transport = FakeBleTransport();
      source = BleHeartRateSource(
        transport,
        scanTimeout: const Duration(seconds: 5),
        reconnectDelays: const [Duration.zero],
      );
      errors = [];
      source.errors.listen(errors.add);

      await source.connectTo(_band);

      // 首次断开触发一次重连,再次断开时重连次数已耗尽。
      transport.dropConnection();
      await pumpEventQueue(times: 20);
      transport.dropConnection();
      await pumpEventQueue(times: 20);

      expect(source.status, HeartRateConnection.disconnected);
      expect(errors, isNotEmpty);
      expect(errors.last, contains('连接已断开'));
    });
  });

  group('自动连接', () {
    test('优先连接广播了心率服务的设备', () async {
      transport.devicesOnStart = [
        const HeartRateDevice(id: 'buds', name: 'AirPods'),
        _band,
      ];

      await source.connect();

      expect(transport.calls, contains('connect:band-1'));
      expect(source.status, HeartRateConnection.connected);
      expect(source.connectedDevice, _band);
    });

    test('扫描不到心率设备时提示', () async {
      source.dispose();
      transport = FakeBleTransport();
      source = BleHeartRateSource(
        transport,
        scanTimeout: const Duration(milliseconds: 50),
        reconnectDelays: const [],
      );
      errors = [];
      source.errors.listen(errors.add);
      transport.devicesOnStart = const [
        HeartRateDevice(id: 'buds', name: 'AirPods'),
      ];

      await source.connect();
      await pumpEventQueue();

      expect(source.status, HeartRateConnection.disconnected);
      expect(errors.single, contains('未发现心率设备'));
    });
  });
}
