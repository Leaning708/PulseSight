/// 一次心率测量结果。
final class HeartRateReading {
  /// 创建一条在 [takenAt] 时刻采集、心率为 [bpm] 的测量记录。
  const HeartRateReading({required this.bpm, required this.takenAt});

  /// 心率值,单位 bpm(次/分钟)。
  final int bpm;

  /// 采集时间。
  final DateTime takenAt;
}
