import '../../domain/models/heart_rate_mode.dart';

/// 可在真实设备与模拟数据源之间切换的能力。
///
/// 切换实现必须保证两种模式互斥:切换前断开旧模式的数据源,
/// 任意时刻只有一个模式在产生心率数据。
abstract interface class HeartRateModeSource {
  /// 当前模式。
  HeartRateMode get mode;

  /// 模式变化流。
  Stream<HeartRateMode> get modeStream;

  /// 切换模式;实现需先断开旧模式的数据源。
  Future<void> setMode(HeartRateMode mode);
}
