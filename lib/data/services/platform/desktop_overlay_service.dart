import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../../../domain/models/heart_rate_connection.dart';
import '../../../domain/models/heart_rate_reading.dart';
import '../../../domain/models/overlay_style.dart';
import '../../repositories/heart_rate_repository.dart';

/// 桌面悬浮窗控制接口,便于 ViewModel 测试时替换。
abstract interface class DesktopOverlay {
  /// 显示悬浮窗。
  Future<void> show({required bool passthrough});

  /// 隐藏悬浮窗(保留副窗口引擎,便于快速再次显示)。
  Future<void> hide();

  /// 设置鼠标穿透。
  Future<void> setPassthrough(bool value);

  /// 推送悬浮窗显示样式。
  Future<void> setStyle(OverlayStyle style);

  /// 释放资源。
  void dispose();
}

/// Windows / macOS 桌面悬浮窗服务(主窗口侧)。
///
/// 负责创建/复用悬浮窗副窗口,并把仓库心率数据经
/// [WindowController.invokeMethod] 推送到副窗口。
/// 副窗口自身的样式(无边框、透明、置顶、穿透)由悬浮窗引擎内的
/// [DesktopOverlayPage] 完成配置。
class DesktopOverlayService implements DesktopOverlay {
  /// 创建服务;[repository] 为心率数据来源。
  DesktopOverlayService({required this._repository});

  final HeartRateRepository _repository;

  /// 副窗口启动参数标识,主入口据此分发悬浮窗引擎。
  static const String overlayWindowArgument = 'overlay';

  /// 数据推送方法名。
  static const String _methodUpdate = 'update';

  /// 穿透设置方法名。
  static const String _methodSetPassthrough = 'setPassthrough';

  /// 副窗口引擎启动后的初始推送重试间隔(引擎启动需数秒)。
  static const List<int> _initialPushDelaysMs = [400, 900, 1600, 2800, 4500];

  WindowController? _overlayWindow;
  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;
  final List<Timer> _initialPushTimers = [];

  int? _lastBpm;
  bool _lastConnected = false;
  OverlayStyle _lastStyle = OverlayStyle.defaults;

  /// 悬浮窗当前是否已创建(含隐藏状态)。
  bool get isShowing => _overlayWindow != null;

  @override
  Future<void> setStyle(OverlayStyle style) async {
    if (_lastStyle == style) return;
    _lastStyle = style;
    _push();
  }

  @override
  Future<void> show({required bool passthrough}) async {
    // passthrough 由悬浮窗引擎在 [DesktopOverlayPage] 中应用,
    // 主窗口侧仅在创建后转发开关状态。
    if (passthrough) {
      unawaited(setPassthrough(true));
    }
    _overlayWindow ??= await WindowController.create(
      const WindowConfiguration(
        arguments: overlayWindowArgument,
        hiddenAtLaunch: true,
      ),
    );
    await _overlayWindow!.show();
    _startForwarding();
    _scheduleInitialPush();
  }

  @override
  Future<void> hide() async {
    _stopForwarding();
    await _overlayWindow?.hide();
  }

  @override
  Future<void> setPassthrough(bool value) async {
    try {
      await _overlayWindow?.invokeMethod<bool>(_methodSetPassthrough, value);
    } on Exception {
      // 副窗口引擎尚未就绪或已退出,忽略。
    }
  }

  @override
  void dispose() {
    _stopForwarding();
    _overlayWindow = null;
  }

  void _startForwarding() {
    _stopForwarding();
    _lastConnected = _repository.status == HeartRateConnection.connected;
    _lastBpm = _lastConnected ? _repository.currentBpm : null;
    _readingsSub = _repository.readings.listen((reading) {
      _lastBpm = reading.bpm;
      _lastConnected = true;
      _push();
    });
    _connectionSub = _repository.connection.listen((status) {
      _lastConnected = status == HeartRateConnection.connected;
      if (!_lastConnected) _lastBpm = null;
      _push();
    });
  }

  void _stopForwarding() {
    _readingsSub?.cancel();
    _readingsSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    for (final timer in _initialPushTimers) {
      timer.cancel();
    }
    _initialPushTimers.clear();
  }

  /// 副窗口引擎启动需要数秒,期间注册的 handler 不可用,
  /// 因此按固定间隔重试推送,直到 handler 就绪并收到最新状态。
  void _scheduleInitialPush() {
    for (final delay in _initialPushDelaysMs) {
      _initialPushTimers.add(Timer(Duration(milliseconds: delay), _push));
    }
  }

  Future<void> _push() async {
    final window = _overlayWindow;
    if (window == null) return;
    try {
      await window.invokeMethod<dynamic>(_methodUpdate, {
        'bpm': _lastBpm,
        'status': _lastConnected ? 'connected' : 'disconnected',
        'style': _lastStyle.toJson(),
      });
    } on Exception {
      // 副窗口引擎尚未就绪(handler 未注册)或已退出,忽略。
    }
  }
}
