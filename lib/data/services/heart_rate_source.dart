import '../../domain/models/heart_rate_connection.dart';

/// 心率数据源抽象。
///
/// 封装“如何拿到心率数据”:当前为模拟实现([SimulatedHeartRateSource]),
/// 后续接入小米手环蓝牙广播时,提供新的 [HeartRateSource] 实现即可,
/// 上层 Repository 与 UI 无需改动。
abstract interface class HeartRateSource {
  /// 心率采样流,每次采样一个 bpm 值。
  Stream<int> get bpmStream;

  /// 连接状态变化流。
  Stream<HeartRateConnection> get connectionStream;

  /// 当前连接状态快照。
  HeartRateConnection get status;

  /// 最近一次心率快照,尚未收到数据时为 null。
  int? get currentBpm;

  /// 开始连接;连接建立后开始产生心率数据。
  Future<void> connect();

  /// 断开连接并停止产生数据。
  Future<void> disconnect();

  /// 释放底层资源,释放后不可再使用。
  void dispose();
}
