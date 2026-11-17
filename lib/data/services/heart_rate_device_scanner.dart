import '../../domain/models/heart_rate_device.dart';

/// 心率设备扫描与指定连接能力。
///
/// 这是真实 BLE 数据源的特有能力;模拟数据源不实现该接口,上层据此
/// 显隐设备选择 UI(与 `HeartRateScenarioSource` 的能力探测方式一致)。
abstract interface class HeartRateDeviceScanner {
  /// 扫描结果,按「心率广播设备优先 + 信号强度降序」排列。
  ///
  /// 新订阅者会先收到最近一次结果,便于设备选择弹窗立即渲染。
  Stream<List<HeartRateDevice>> get scanResults;

  /// 扫描状态变化流;新订阅者会先收到当前状态。
  Stream<bool> get scanningStream;

  /// 当前是否正在扫描。
  bool get isScanning;

  /// 当前连接目标(正在连接或已连接);未连接时为 null。
  HeartRateDevice? get connectedDevice;

  /// 扫描 / 连接过程中的错误信息。
  Stream<String> get errors;

  /// 开始扫描。
  ///
  /// 蓝牙不可用、未开启或权限被拒绝时抛出异常,由上层转成界面提示。
  Future<void> startScan();

  /// 停止扫描;未在扫描时为空操作。
  Future<void> stopScan();

  /// 连接指定设备。
  ///
  /// 连接是异步过程,失败通过 [errors] 通知,不向调用方抛出。
  Future<void> connectTo(HeartRateDevice device);
}
