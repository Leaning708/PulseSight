import '../../domain/models/heart_rate_connection.dart';
import '../../domain/models/heart_rate_reading.dart';
import '../services/heart_rate_scenario_source.dart';
import '../services/heart_rate_source.dart';

/// 心率数据仓库。
///
/// 对上层屏蔽具体数据来源(当前为模拟源,后续替换为小米手环 BLE 广播),
/// 并把原始 bpm 采样封装为 [HeartRateReading]。
class HeartRateRepository {
  /// 创建仓库,持有唯一的数据来源 [source]。
  HeartRateRepository({required this._source});

  final HeartRateSource _source;

  /// 心率采样流,附带采集时间。
  Stream<HeartRateReading> get readings => _source.bpmStream.map(
    (bpm) => HeartRateReading(bpm: bpm, takenAt: DateTime.now()),
  );

  /// 连接状态变化流。
  Stream<HeartRateConnection> get connection => _source.connectionStream;

  /// 当前连接状态快照。
  HeartRateConnection get status => _source.status;

  /// 最近一次心率快照,尚未收到数据时为 null。
  int? get currentBpm => _source.currentBpm;

  /// 若数据源支持模拟场景切换,返回该能力;真实数据源没有场景概念,
  /// 返回 null,上层据此呈现或隐藏场景切换 UI。
  HeartRateScenarioSource? get scenarioSource {
    final source = _source;
    return source is HeartRateScenarioSource
        ? source as HeartRateScenarioSource
        : null;
  }

  /// 开始连接数据源。
  Future<void> connect() => _source.connect();

  /// 断开数据源。
  Future<void> disconnect() => _source.disconnect();

  /// 释放资源。
  void dispose() => _source.dispose();
}
