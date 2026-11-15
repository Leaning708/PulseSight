import 'dart:async';
import 'dart:math';

import 'heart_rate_scenario_source.dart';
import 'heart_rate_source.dart';
import '../../domain/models/heart_rate_connection.dart';
import '../../domain/models/heart_rate_scenario.dart';

/// 模拟心率数据源。
///
/// 用"随机游走 + 向场景基准值回归"的算法生成贴近真实生理规律的数据,
/// 支持低 / 中 / 高([HeartRateScenario])三档场景切换,模拟"已连接手环"
/// 的场景:连接建立后有约 1.5 秒的 connecting 阶段,随后按固定间隔采样。
/// 时序参数与初始场景可在构造时注入,便于测试。
class SimulatedHeartRateSource
    implements HeartRateSource, HeartRateScenarioSource {
  /// 创建模拟数据源。
  ///
  /// [connectDelay] 模拟连接握手耗时;[sampleInterval] 为采样间隔;
  /// [scenario] 为初始模拟场景;[random] 用于注入随机数生成器(测试中可固定种子)。
  SimulatedHeartRateSource({
    this.connectDelay = const Duration(milliseconds: 1500),
    this.sampleInterval = const Duration(milliseconds: 800),
    this._scenario = HeartRateScenario.medium,
    Random? random,
  }) : _random = random ?? Random();

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
  HeartRateScenario _scenario;
  int _bpm = HeartRateScenario.medium.baseBpm;

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  HeartRateConnection get status => _status;

  @override
  int? get currentBpm => _status == HeartRateConnection.connected ? _bpm : null;

  @override
  HeartRateScenario get scenario => _scenario;

  @override
  void setScenario(HeartRateScenario scenario) {
    _scenario = scenario;
  }

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
    // 连接建立时以场景基准值起步,重连后即刻反映当前场景的水平。
    _bpm = _scenario.baseBpm;
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

  /// 生成下一个 bpm:随机游走 + 向场景基准值缓慢回归。
  ///
  /// 当前值处于场景区间内时严格钳制在区间内;场景刚切换时当前值可能
  /// 仍在旧区间之外,此时不钳制,由回归项逐拍自然过渡,避免瞬间跳变。
  int _nextBpm() {
    final drift = _random.nextInt(5) - 2; // -2 ~ +2
    final pull = ((_scenario.baseBpm - _bpm) / 15).round();
    final next = _bpm + drift + pull;
    final inRange = _bpm >= _scenario.minBpm && _bpm <= _scenario.maxBpm;
    return inRange ? next.clamp(_scenario.minBpm, _scenario.maxBpm) : next;
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
