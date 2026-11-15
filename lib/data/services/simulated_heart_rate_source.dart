import 'dart:async';
import 'dart:math';

import 'heart_rate_source.dart';
import '../../domain/models/heart_rate_connection.dart';

/// 模拟心率数据源。
///
/// 用随机游走生成贴近静息心率的数据,模拟“已连接手环”的场景:
/// 连接建立后有约 1.5 秒的 connecting 阶段,随后按固定间隔采样。
/// 时序参数可在构造时注入,便于测试。
class SimulatedHeartRateSource implements HeartRateSource {
  /// 创建模拟数据源。
  ///
  /// [connectDelay] 模拟连接握手耗时;[sampleInterval] 为采样间隔;
  /// [random] 用于注入随机数生成器(测试中可固定种子)。
  SimulatedHeartRateSource({
    this.connectDelay = const Duration(milliseconds: 1500),
    this.sampleInterval = const Duration(milliseconds: 800),
    Random? random,
  }) : _random = random ?? Random();

  /// bpm 随机游走的下限。
  static const int minBpm = 55;

  /// bpm 随机游走的上限。
  static const int maxBpm = 105;

  /// 静息心率基准值,bpm 会缓慢向它回归。
  static const int restingBpm = 72;

  /// 连接建立后的首个采样值。
  static const int initialBpm = 72;

  final Duration connectDelay;
  final Duration sampleInterval;
  final Random _random;

  final StreamController<int> _bpmController =
      StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connectionController =
      StreamController<HeartRateConnection>.broadcast();

  Timer? _connectTimer;
  Timer? _sampleTimer;
  HeartRateConnection _status = HeartRateConnection.disconnected;
  int _bpm = initialBpm;

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  HeartRateConnection get status => _status;

  @override
  int? get currentBpm =>
      _status == HeartRateConnection.connected ? _bpm : null;

  @override
  Future<void> connect() async {
    if (_status != HeartRateConnection.disconnected) return;
    _setStatus(HeartRateConnection.connecting);
    _connectTimer = Timer(connectDelay, _onConnected);
  }

  @override
  Future<void> disconnect() async {
    _cancelTimers();
    _setStatus(HeartRateConnection.disconnected);
  }

  @override
  void dispose() {
    _cancelTimers();
    _bpmController.close();
    _connectionController.close();
  }

  void _onConnected() {
    _bpm = initialBpm;
    _setStatus(HeartRateConnection.connected);
    _emitBpm();
    _sampleTimer = Timer.periodic(sampleInterval, (_) => _emitBpm());
  }

  void _emitBpm() {
    _bpm = _nextBpm();
    if (!_bpmController.isClosed) {
      _bpmController.add(_bpm);
    }
  }

  /// 生成下一个 bpm:随机游走 + 向静息心率缓慢回归,并限制在合理区间。
  int _nextBpm() {
    final drift = _random.nextInt(5) - 2; // -2 ~ +2
    final pull = ((restingBpm - _bpm) / 15).round();
    return (_bpm + drift + pull).clamp(minBpm, maxBpm);
  }

  void _setStatus(HeartRateConnection status) {
    if (_status == status) return;
    _status = status;
    if (!_connectionController.isClosed) {
      _connectionController.add(status);
    }
  }

  void _cancelTimers() {
    _connectTimer?.cancel();
    _connectTimer = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }
}
