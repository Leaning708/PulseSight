import '../../domain/models/heart_rate_device.dart';

/// BLE 传输层错误:携带可直接展示给用户的中文说明。
class BleException implements Exception {
  /// 创建错误。
  const BleException(this.message);

  /// 面向用户的错误描述。
  final String message;

  @override
  String toString() => message;
}

/// BLE 心率设备传输抽象。
///
/// 封装「扫描 / 连接 / 订阅标准心率服务」等插件相关操作,
/// 使 `BleHeartRateSource` 的连接状态机不依赖具体蓝牙实现,
/// 从而可以在无蓝牙硬件的环境中用 Fake 测试。
abstract interface class BleHeartRateTransport {
  /// 扫描结果流。
  Stream<List<HeartRateDevice>> get scanResults;

  /// 开始扫描;实现方负责在内部超时后停止扫描。
  Future<void> startScan();

  /// 停止扫描。
  Future<void> stopScan();

  /// 连接设备并订阅心率测量通知。
  ///
  /// 返回的心率采样流在设备断开时结束;连接或订阅失败时抛出
  /// [BleException]。
  Future<Stream<int>> connect(HeartRateDevice device);

  /// 断开当前设备并释放连接资源。
  Future<void> disconnect();

  /// 释放全部资源,释放后不可再使用。
  void dispose();
}
