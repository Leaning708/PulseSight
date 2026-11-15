/// 手环连接状态。
enum HeartRateConnection {
  /// 未连接。
  disconnected,

  /// 正在建立连接。
  connecting,

  /// 已连接,正在接收心率数据。
  connected,
}
