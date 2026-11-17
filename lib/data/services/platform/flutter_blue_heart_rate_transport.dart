import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../domain/models/heart_rate_device.dart';
import '../ble_heart_rate_transport.dart';
import '../heart_rate_measurement.dart';

/// 基于 flutter_blue_plus 的 BLE 心率传输实现。
///
/// 只实现标准心率服务(0x180D / 0x2A37)的扫描与订阅,兼容小米手环
/// 「心率广播」、心率带等遵循 Bluetooth SIG 心率规范的设备。
///
/// 扫描不做服务过滤:部分设备(尤其旧固件)不会在广播包中声明 0x180D,
/// 若在平台层过滤会直接搜不到;改由上层按 `advertisesHeartRate` 排序与过滤,
/// 并允许用户切换「显示全部蓝牙设备」手动选择。
class FlutterBlueHeartRateTransport implements BleHeartRateTransport {
  /// 标准心率服务 UUID。
  static const String heartRateServiceUuid = '180D';

  /// 标准心率测量特征值 UUID。
  static const String heartRateMeasurementUuid = '2A37';

  static final Guid _heartRateService = Guid(heartRateServiceUuid);

  static final Guid _heartRateMeasurement = Guid(heartRateMeasurementUuid);

  final StreamController<List<HeartRateDevice>> _scanController =
      StreamController<List<HeartRateDevice>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  BluetoothDevice? _device;

  StreamController<int>? _bpmController;

  StreamSubscription<List<int>>? _valueSubscription;

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  bool _disposed = false;

  @override
  Stream<List<HeartRateDevice>> get scanResults => _scanController.stream;

  @override
  Future<void> startScan() async {
    if (_disposed) throw const BleException('蓝牙连接已释放');
    if (!await FlutterBluePlus.isSupported) {
      throw const BleException('当前设备不支持蓝牙低功耗(BLE)');
    }
    await _ensureAdapterOn();
    _scanSubscription ??= FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: (Object error, StackTrace _) {
        if (!_scanController.isClosed) {
          _scanController.addError(BleException(_describe(error)));
        }
      },
    );
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } on Object catch (error) {
      throw BleException(_describe(error));
    }
  }

  @override
  Future<void> stopScan() async {
    if (_disposed) return;
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } on Object {
      // 停止扫描失败不影响后续连接,忽略即可。
    }
  }

  @override
  Future<Stream<int>> connect(HeartRateDevice device) async {
    if (_disposed) throw const BleException('蓝牙连接已释放');
    await stopScan();
    await disconnect();

    final btDevice = BluetoothDevice.fromId(device.id);
    try {
      await btDevice.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
      );

      final services = await btDevice.discoverServices();
      final measurement = _findHeartRateMeasurement(services);
      if (measurement == null) {
        throw const BleException('未找到心率测量服务(0x2A37),请确认设备已开启「心率广播」');
      }

      final bpmController = StreamController<int>.broadcast();
      final valueSubscription = measurement.onValueReceived.listen((value) {
        final bpm = parseHeartRateMeasurement(value);
        if (bpm != null && isValidHeartRate(bpm) && !bpmController.isClosed) {
          bpmController.add(bpm);
        }
      });
      final connectionSubscription = btDevice.connectionState.listen((state) {
        // 设备侧断开(走出范围 / 关机)时结束采样流,由数据源决定是否重连。
        if (state == BluetoothConnectionState.disconnected &&
            !bpmController.isClosed) {
          unawaited(bpmController.close());
        }
      });

      _device = btDevice;
      _bpmController = bpmController;
      _valueSubscription = valueSubscription;
      _connectionSubscription = connectionSubscription;

      await measurement.setNotifyValue(true);
      return bpmController.stream;
    } on Object catch (error) {
      await _teardownConnection();
      throw error is BleException ? error : BleException(_describe(error));
    }
  }

  @override
  Future<void> disconnect() => _teardownConnection();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    unawaited(_teardownConnection());
    unawaited(_scanController.close());
  }

  /// 等待蓝牙适配器就绪;超时后给出权限 / 开关提示。
  Future<void> _ensureAdapterOn() async {
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) return;
    try {
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const BleException('蓝牙未开启或未授权,请在系统设置中允许 PulseSight 使用蓝牙');
    }
  }

  /// 把扫描结果转换为领域模型并按「心率设备优先 + 信号强度降序」排序。
  void _onScanResults(List<ScanResult> results) {
    if (_scanController.isClosed) return;
    final devices = <String, HeartRateDevice>{};
    for (final result in results) {
      final advertisement = result.advertisementData;
      final id = result.device.remoteId.str;
      final name = advertisement.advName.isNotEmpty
          ? advertisement.advName
          : result.device.platformName;
      final advertisesHeartRate =
          advertisement.serviceUuids.contains(_heartRateService) ||
          advertisement.serviceData.containsKey(_heartRateService);
      devices[id] = HeartRateDevice(
        id: id,
        name: name,
        rssi: result.rssi,
        advertisesHeartRate: advertisesHeartRate,
      );
    }

    final sorted = devices.values.toList()
      ..sort((a, b) {
        if (a.advertisesHeartRate != b.advertisesHeartRate) {
          return a.advertisesHeartRate ? -1 : 1;
        }
        return (b.rssi ?? -1000).compareTo(a.rssi ?? -1000);
      });
    _scanController.add(List.unmodifiable(sorted));
  }

  /// 优先在 0x180D 服务内查找测量特征值,找不到再按特征值 UUID 全表兜底。
  BluetoothCharacteristic? _findHeartRateMeasurement(
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      if (service.uuid != _heartRateService) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == _heartRateMeasurement) {
          return characteristic;
        }
      }
    }
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == _heartRateMeasurement) {
          return characteristic;
        }
      }
    }
    return null;
  }

  Future<void> _teardownConnection() async {
    final valueSubscription = _valueSubscription;
    _valueSubscription = null;
    await valueSubscription?.cancel();

    final connectionSubscription = _connectionSubscription;
    _connectionSubscription = null;
    await connectionSubscription?.cancel();

    final bpmController = _bpmController;
    _bpmController = null;
    if (bpmController != null && !bpmController.isClosed) {
      await bpmController.close();
    }

    final device = _device;
    _device = null;
    if (device != null) {
      try {
        // 绕过 FBP 的 GATT 操作队列:Windows 上若有卡住的读写 / 服务发现,
        // 排队的 disconnect 可能一直轮不到,表现为「App 退出前其他中心设备
        // 连不上」。queue:false 让断连指令立即下发。
        await device.disconnect(timeout: 10, queue: false);
      } on Object {
        // 兜底再走一次常规队列,覆盖平台侧瞬时失败。
        try {
          await device.disconnect(timeout: 10);
        } on Object {
          // 设备可能已自行断开,忽略清理失败。
        }
      }
    }
  }

  /// 把插件异常转换为面向用户的中文描述。
  String _describe(Object error) {
    if (error is BleException) return error.message;
    if (error is FlutterBluePlusException) {
      final detail = error.description?.trim();
      if (detail != null && detail.isNotEmpty) {
        return '蓝牙操作失败:$detail';
      }
      return '蓝牙操作失败(${error.function})';
    }
    return '蓝牙操作失败:$error';
  }
}
