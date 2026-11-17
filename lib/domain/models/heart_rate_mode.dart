/// 心率数据源模式。
enum HeartRateMode {
  /// 连接真实 BLE 心率设备(小米手环「心率广播」等)。
  real,

  /// 使用内置模拟心率,便于无设备时演示与调试。
  simulated;

  /// 从持久化字符串解析;未知值回退为 [real]。
  static HeartRateMode fromString(String? value) {
    return switch (value) {
      'simulated' => HeartRateMode.simulated,
      _ => HeartRateMode.real,
    };
  }
}
