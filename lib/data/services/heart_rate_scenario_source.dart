import '../../domain/models/heart_rate_scenario.dart';

/// 支持"模拟场景"能力的心率数据源。
///
/// 场景切换是模拟源特有的能力,真实 BLE 数据源不存在该概念,
/// 因此与 [HeartRateSource] 分离为独立能力接口:上层经
/// Repository 的能力探测呈现或隐藏场景切换 UI,替换数据源时无需改动。
abstract interface class HeartRateScenarioSource {
  /// 当前模拟场景。
  HeartRateScenario get scenario;

  /// 切换模拟场景;已连接时从下一个采样周期起按新场景生成。
  void setScenario(HeartRateScenario scenario);
}
