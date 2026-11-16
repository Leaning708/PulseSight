import 'dart:async';
import 'dart:io';

import '../../../domain/models/heart_rate_connection.dart';
import '../../../domain/models/heart_rate_reading.dart';
import '../../../domain/models/overlay_style.dart';
import '../../repositories/heart_rate_repository.dart';
import 'desktop_overlay_service.dart';
import 'overlay_ipc.dart';

/// Windows 桌面悬浮窗服务:**独立进程**运行悬浮窗。
///
/// 为什么不用 macOS 那套同进程副窗口(desktop_multi_window):Flutter 的
/// Windows 嵌入层不支持单进程多引擎 —— 第二个视图会重置平台线程的 EGL
/// current context,污染首个引擎的 raster 线程,约 30–200 秒后进程级崩溃
/// (`flutter_windows.dll` + `0xc0000005`)。把悬浮窗放进**独立进程**后,
/// EGL/ANGLE 状态天然隔离,同时换来崩溃隔离(悬浮窗挂了不影响主界面)。
///
/// TODO(窗口方案):这是**临时方案**。官方 Desktop Windowing API 转正
/// (单引擎多视图,`flutter config --enable-windowing`)后应改回进程内实现,
/// 删除本文件与 `overlay_ipc.dart`,详见 TODO.md。
///
/// 主进程职责:拉起/回收子进程、把心率与样式快照经 IPC 推给子进程、
/// 转发显示/隐藏与鼠标穿透指令。子进程侧见 OverlayProcessPage。
class WindowsOverlayProcessService implements DesktopOverlay {
  /// 创建服务;[repository] 为心率数据来源。
  ///
  /// [linkFactory] 与 [launcher] 仅供测试注入,生产环境使用默认实现。
  WindowsOverlayProcessService({
    required this._repository,
    OverlayHost Function()? linkFactory,
    this._executablePath,
  }) : _createLink = linkFactory ?? OverlayHostLink.new;

  final HeartRateRepository _repository;
  final OverlayHost Function() _createLink;
  final String? _executablePath;

  /// 子进程启动失败后的重试退避(避免崩溃循环)。
  static const List<int> _restartBackoffMs = [500, 1500, 4000];

  OverlayHost? _link;
  StreamSubscription<OverlayMessage>? _messageSub;
  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;

  int? _lastBpm;
  bool _lastConnected = false;
  bool _passthrough = false;
  OverlayStyle _lastStyle = OverlayStyle.defaults;

  /// 期望的可见状态;子进程就绪后按此状态补发。
  bool _shouldShow = false;

  /// 连续启动失败次数,用于退避与熔断。
  int _startFailures = 0;

  bool _disposed = false;

  /// 子进程当前是否已连接。
  bool get isRunning => _link?.isConnected ?? false;

  @override
  Future<void> show({required bool passthrough}) async {
    if (_disposed) return;
    _shouldShow = true;
    _passthrough = passthrough;
    _startForwarding();
    final link = await _ensureLink();
    if (link == null) return;
    link.send({'type': OverlayMessageType.show});
    link.send({'type': OverlayMessageType.passthrough, 'value': passthrough});
    _pushState();
  }

  @override
  Future<void> hide() async {
    _shouldShow = false;
    _stopForwarding();
    _link?.send({'type': OverlayMessageType.hide});
  }

  @override
  Future<void> setPassthrough(bool value) async {
    if (_passthrough == value) return;
    _passthrough = value;
    _link?.send({'type': OverlayMessageType.passthrough, 'value': value});
  }

  @override
  Future<void> setStyle(OverlayStyle style) async {
    if (_lastStyle == style) return;
    _lastStyle = style;
    _pushState();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopForwarding();
    unawaited(_messageSub?.cancel());
    _messageSub = null;
    unawaited(_link?.close());
    _link = null;
  }

  // ---- 子进程生命周期 ----

  /// 确保子进程已启动并连接;失败时按退避重试,超过次数则放弃本次操作。
  Future<OverlayHost?> _ensureLink() async {
    final existing = _link;
    if (existing != null && existing.isConnected) return existing;

    if (_startFailures >= _restartBackoffMs.length) return null;

    final link = _createLink();
    _link = link;
    _messageSub?.cancel();
    _messageSub = link.messages.listen(_onMessage);

    final executable = _executablePath ?? Platform.resolvedExecutable;
    final ok = await link.start(executable: executable);
    if (!ok) {
      _startFailures++;
      unawaited(link.close());
      if (identical(_link, link)) _link = null;
      if (_startFailures < _restartBackoffMs.length) {
        await Future<void>.delayed(
          Duration(milliseconds: _restartBackoffMs[_startFailures - 1]),
        );
      }
      return null;
    }

    _startFailures = 0;
    // 子进程可能提前退出:清理引用,下次显示时重新拉起。
    unawaited(
      link.exit?.then((_) {
        if (identical(_link, link)) {
          _link = null;
          _messageSub?.cancel();
          _messageSub = null;
        }
      }),
    );
    return link;
  }

  void _onMessage(OverlayMessage message) {
    // 目前只有 ready 需要对主进程作出反应:补发当前显示状态与快照。
    if (message['type'] != OverlayMessageType.ready) return;
    final link = _link;
    if (link == null || !link.isConnected) return;
    if (_shouldShow) {
      link.send({'type': OverlayMessageType.show});
      link.send({
        'type': OverlayMessageType.passthrough,
        'value': _passthrough,
      });
      _pushState();
    } else {
      link.send({'type': OverlayMessageType.hide});
    }
  }

  // ---- 心率转发 ----

  void _startForwarding() {
    _stopForwarding();
    _lastConnected = _repository.status == HeartRateConnection.connected;
    _lastBpm = _lastConnected ? _repository.currentBpm : null;
    _readingsSub = _repository.readings.listen((reading) {
      _lastBpm = reading.bpm;
      _lastConnected = true;
      _pushState();
    });
    _connectionSub = _repository.connection.listen((status) {
      _lastConnected = status == HeartRateConnection.connected;
      if (!_lastConnected) _lastBpm = null;
      _pushState();
    });
  }

  void _stopForwarding() {
    _readingsSub?.cancel();
    _readingsSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
  }

  /// 推送心率/连接/样式快照;子进程未就绪时消息被丢弃,就绪后会补发。
  void _pushState() {
    _link?.send({
      'type': OverlayMessageType.state,
      'bpm': _lastBpm,
      'status': _lastConnected
          ? 'connected'
          : HeartRateConnection.disconnected.name,
      'style': _lastStyle.toJson(),
    });
  }
}
