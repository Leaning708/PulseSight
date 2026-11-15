import '../../domain/models/heart_rate_connection.dart';
import '../../domain/models/heart_rate_reading.dart';
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
  Stream<HeartRateReading> get readings =>
      _source.bpmStream.map((bpm) => HeartRateReading(bpm: bpm, takenAt: DateTime.now()));

  /// 连接状态变化流。
  Stream<HeartRateConnection> get connection => _source.connectionStream;

  /// 当前连接状态快照。
  HeartRateConnection get status => _source.status;

  /// 最近一次心率快照,尚未收到数据时为 null。
  int? get currentBpm => _source.currentBpm;

  /// 开始连接数据源。
  Future<void> connect() => _source.connect();

  /// 断开数据源。
  Future<void> disconnect() => _source.disconnect();

  /// 释放资源。
  void dispose() => _source.dispose();
}
