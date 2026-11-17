/// 心率测量值的最小合法范围(bpm)。
///
/// 标准心率服务未佩戴时可能上报 0,过大的值则通常是解析错位,
/// 两者都不应进入采样流污染图表。
const int minValidHeartRate = 1;

/// 心率测量值的最大合法范围(bpm)。
const int maxValidHeartRate = 300;

/// 解析标准 BLE 心率测量特征值(0x2A37)并返回 bpm。
///
/// 字节 0 为 flags:bit0 表示心率值采用 16 位小端格式(0 = 8 位,1 = 16 位)。
/// 数据长度不足时返回 null。
///
/// 参考 Bluetooth SIG: Heart Rate Measurement characteristic。
int? parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) return null;
  final flags = data[0];
  final isUint16 = flags & 0x01 != 0;
  if (isUint16) {
    if (data.length < 3) return null;
    return data[1] | (data[2] << 8);
  }
  if (data.length < 2) return null;
  return data[1];
}

/// 判断 bpm 是否在可信范围内。
bool isValidHeartRate(int bpm) =>
    bpm >= minValidHeartRate && bpm <= maxValidHeartRate;
