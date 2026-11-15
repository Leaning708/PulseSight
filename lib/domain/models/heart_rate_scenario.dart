/// 模拟心率场景:低 / 中 / 高三档。
///
/// 模拟心率是本应用的产品功能,场景描述不同的心率水平
/// (静息/睡眠、日常活动、运动状态),各档位携带模拟参数:
/// 采样值围绕 [baseBpm] 波动,并被限制在 [minBpm] ~ [maxBpm] 区间内。
enum HeartRateScenario {
  /// 低心率:静息 / 睡眠。
  low(45, 62, 52),

  /// 中心率:日常活动,默认档位。
  medium(62, 95, 72),

  /// 高心率:运动状态。
  high(118, 175, 148);

  /// 创建场景;[baseBpm] 为波动回归的基准值。
  const HeartRateScenario(this.minBpm, this.maxBpm, this.baseBpm);

  /// 该场景下 bpm 的下限。
  final int minBpm;

  /// 该场景下 bpm 的上限。
  final int maxBpm;

  /// 该场景的基准心率,采样值围绕它缓慢波动。
  final int baseBpm;

  /// 从持久化的字符串还原;无法识别时回退为 [HeartRateScenario.medium]。
  static HeartRateScenario fromString(String? value) =>
      HeartRateScenario.values.firstWhere(
        (v) => v.name == value,
        orElse: () => HeartRateScenario.medium,
      );
}
