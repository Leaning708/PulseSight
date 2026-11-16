import 'dart:async';

import 'package:pulse_sight/data/services/heart_rate_source.dart';
import 'package:pulse_sight/data/services/platform/overlay_ipc.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';

/// 可控心率数据源:测试中按需推送读数与连接状态。
class FakeHeartRateSource implements HeartRateSource {
  final StreamController<int> _bpm = StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connection =
      StreamController<HeartRateConnection>.broadcast();

  HeartRateConnection _status = HeartRateConnection.disconnected;
  int? _currentBpm;

  @override
  Stream<int> get bpmStream => _bpm.stream;

  @override
  Stream<HeartRateConnection> get connectionStream => _connection.stream;

  @override
  HeartRateConnection get status => _status;

  @override
  int? get currentBpm => _currentBpm;

  /// 推送一次读数(默认同时置为已连接)。
  void emitBpm(int bpm, {HeartRateConnection? status}) {
    if (status != null && status != _status) {
      _status = status;
      _connection.add(status);
    } else if (status == null) {
      _status = HeartRateConnection.connected;
      _connection.add(_status);
    }
    _currentBpm = bpm;
    _bpm.add(bpm);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    _status = HeartRateConnection.disconnected;
    _currentBpm = null;
    _connection.add(_status);
  }

  @override
  void dispose() {
    _bpm.close();
    _connection.close();
  }
}

/// 假的主进程侧链路:记录发送内容,并可模拟子进程就绪/退出。
class FakeOverlayHost implements OverlayHost {
  FakeOverlayHost();

  final List<OverlayMessage> sent = [];
  final List<String> started = [];
  final StreamController<OverlayMessage> _messages =
      StreamController<OverlayMessage>.broadcast();

  /// start 的返回值,测试可置为 false 模拟启动失败。
  bool startResult = true;

  bool closed = false;
  bool _connected = false;

  @override
  Stream<OverlayMessage> get messages => _messages.stream;

  @override
  bool get isConnected => startResult && !closed;

  @override
  Future<void>? get exit => null;

  @override
  Future<bool> start({required String executable}) async {
    started.add(executable);
    _connected = startResult;
    return startResult;
  }

  @override
  void send(OverlayMessage message) {
    if (!_connected || closed) return;
    sent.add(message);
  }

  /// 模拟子进程发来消息。
  void emit(OverlayMessage message) => _messages.add(message);

  @override
  Future<void> close() async {
    closed = true;
    _connected = false;
    if (!_messages.isClosed) await _messages.close();
  }
}
