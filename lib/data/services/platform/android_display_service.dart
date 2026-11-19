import 'dart:async';
import 'dart:ui' show Offset, PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../domain/models/heart_rate_connection.dart';
import '../../../domain/models/heart_rate_reading.dart';
import '../../../domain/models/overlay_style.dart';
import '../../repositories/heart_rate_repository.dart';

/// Android 显示端(悬浮窗 + 状态栏持续通知)接口,便于 ViewModel 测试时替换。
abstract interface class AndroidDisplay {
  /// 确保悬浮窗权限已授予;跳转系统设置后返回是否已授权。
  Future<bool> ensureOverlayPermission();

  /// 显示心率悬浮窗并开始转发数据。
  ///
  /// [position] 为恢复的上次位置(逻辑像素),null 用系统默认位置;
  /// [touchPassthrough]、[edgeSnap] 为显示时生效的交互选项。
  Future<void> showOverlay({
    Offset? position,
    bool touchPassthrough = false,
    bool edgeSnap = true,
  });

  /// 关闭心率悬浮窗。
  Future<void> hideOverlay();

  /// 开关悬浮窗触摸穿透(开启后触摸作用于下层应用,悬浮窗不可拖动)。
  Future<void> setTouchPassthrough(bool enabled);

  /// 开关拖动结束后的左右边缘吸附。
  Future<void> setEdgeSnap(bool enabled);

  /// 悬浮窗位置回传流(逻辑像素);拖动与吸附结束各回传一次。
  Stream<Offset> get overlayPositionStream;

  /// 开关状态栏心率通知;开启失败(未授予通知权限)时返回 false。
  Future<bool> setStatusBarEnabled(bool enabled);

  /// 推送悬浮窗显示样式。
  Future<void> setStyle(OverlayStyle style);

  /// 释放资源。
  void dispose();
}

/// Android 显示端服务。
///
/// 悬浮窗:经 [FlutterOverlayWindow.showOverlay] 启动独立 isolate 的
/// 悬浮窗引擎,数据用 [FlutterOverlayWindow.shareData] 推送;
/// 状态栏:经 `pulsesight/status_bar` MethodChannel 驱动原生持续通知。
class AndroidDisplayService implements AndroidDisplay {
  /// 创建服务;[repository] 为心率数据来源。
  AndroidDisplayService({required this._repository});

  final HeartRateRepository _repository;

  /// 悬浮窗当前的位置 / 穿透 / 吸附状态。
  ///
  /// 窗口可能尚未创建或已关闭,这两项用来记住「下次显示时该用什么」。
  Offset? _position;
  bool _touchPassthrough = false;
  bool _edgeSnap = true;

  final StreamController<Offset> _positionController =
      StreamController<Offset>.broadcast();
  StreamSubscription<dynamic>? _overlayMessageSub;

  /// 位置轮询定时器:显示期间定期读回窗口位置。
  Timer? _positionPollTimer;

  /// 上一次上报的位置,用于去重(避免每轮都重复落盘)。
  Offset? _lastReportedPosition;

  static const MethodChannel _statusBarChannel = MethodChannel(
    'pulsesight/status_bar',
  );

  /// 悬浮窗初始尺寸(逻辑像素)。
  ///
  /// 取样式默认背景板尺寸,不另写一份数字:实际尺寸随 [setStyle] 下发
  /// 的样式变化,这里只负责「先按默认大小把窗口开出来」。
  static const Size overlaySize = Size(
    OverlayStyle.defaultBackgroundWidth,
    OverlayStyle.defaultBackgroundHeight,
  );

  /// 悬浮窗引擎启动后的初始推送重试间隔。
  static const List<int> _initialOverlayPushDelaysMs = [500, 1200, 2500, 4000];

  StreamSubscription<HeartRateReading>? _overlayReadingsSub;
  StreamSubscription<HeartRateConnection>? _overlayConnectionSub;
  StreamSubscription<HeartRateReading>? _statusReadingsSub;
  StreamSubscription<HeartRateConnection>? _statusConnectionSub;
  final List<Timer> _initialOverlayPushTimers = [];

  int? _lastBpm;
  HeartRateConnection _lastStatus = HeartRateConnection.disconnected;
  OverlayStyle _lastStyle = OverlayStyle.defaults;

  @override
  Future<void> setStyle(OverlayStyle style) async {
    if (_lastStyle == style) return;
    final sizeChanged =
        _lastStyle.backgroundWidth != style.backgroundWidth ||
        _lastStyle.backgroundHeight != style.backgroundHeight;
    _lastStyle = style;
    _shareOverlayState();
    if (sizeChanged) {
      // 背景板尺寸变化时同步调整悬浮窗窗口大小。
      final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
      try {
        await FlutterOverlayWindow.resizeOverlay(
          (style.backgroundWidth * dpr).round(),
          (style.backgroundHeight * dpr).round(),
          true,
        );
      } on Exception {
        // 悬浮窗未显示,忽略。
      }
    }
  }

  @override
  Future<bool> ensureOverlayPermission() async {
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    await FlutterOverlayWindow.requestPermission();
    return FlutterOverlayWindow.isPermissionGranted();
  }

  @override
  Stream<Offset> get overlayPositionStream => _positionController.stream;

  @override
  Future<void> setTouchPassthrough(bool enabled) async {
    _touchPassthrough = enabled;
    try {
      await FlutterOverlayWindow.updateFlag(
        enabled ? OverlayFlag.clickThrough : OverlayFlag.defaultFlag,
      );
    } on Exception {
      // 悬浮窗未显示时无窗口可更新,忽略;下次显示时会带上该状态。
    }
  }

  @override
  Future<void> setEdgeSnap(bool enabled) async {
    _edgeSnap = enabled;
    try {
      await FlutterOverlayWindow.setPositionGravity(
        enabled ? PositionGravity.auto : PositionGravity.none,
      );
    } on Exception {
      // 同上:窗口不存在时忽略,显示时会带入。
    }
  }

  @override
  Future<void> showOverlay({
    Offset? position,
    bool touchPassthrough = false,
    bool edgeSnap = true,
  }) async {
    _position = position;
    _touchPassthrough = touchPassthrough;
    _edgeSnap = edgeSnap;
    // showOverlay 的尺寸单位是物理像素,需按主窗口 DPR 从逻辑像素换算。
    final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final widthPx = (overlaySize.width * dpr).round();
    final heightPx = (overlaySize.height * dpr).round();
    // 位置是「相对窗口 gravitiy(居中)的偏移」,单位逻辑像素,允许为负值,
    // 因此不在 Dart 侧夹取(会把贴左边缘的负偏移压成 0);越界由原生
    // clampParamsToScreen 按当前方向处理(见补丁说明)。
    final startPosition = _position;
    await FlutterOverlayWindow.showOverlay(
      height: heightPx,
      width: widthPx,
      enableDrag: true,
      positionGravity: _edgeSnap ? PositionGravity.auto : PositionGravity.none,
      flag: _touchPassthrough
          ? OverlayFlag.clickThrough
          : OverlayFlag.defaultFlag,
      // 恢复上次位置;首次显示沿用系统默认位置。
      startPosition: startPosition == null
          ? null
          : OverlayPosition(startPosition.dx, startPosition.dy),
      overlayTitle: 'PulseSight 心率悬浮窗',
      visibility: NotificationVisibility.visibilitySecret,
    );
    _listenOverlayPosition();
    _startPositionPolling();
    _startOverlayForwarding();
    _scheduleInitialOverlayPush();

    // 已知竞态:主应用切后台的瞬间启动服务,FlutterView 可能停留在
    // 零尺寸(渲染空白且不响应触摸);延迟用 resizeOverlay 触发一次
    // 重布局将其唤醒。
    Future.delayed(const Duration(milliseconds: 800), () async {
      try {
        await FlutterOverlayWindow.resizeOverlay(widthPx, heightPx, true);
      } on Exception {
        // 悬浮窗已被用户关闭,忽略。
      }
    });
  }

  @override
  Future<void> hideOverlay() async {
    _stopPositionPolling();
    _stopOverlayForwarding();
    await FlutterOverlayWindow.closeOverlay();
  }

  /// 开始轮询悬浮窗位置。
  ///
  /// 插件把「窗口位置」放在悬浮窗服务里,原生推送给 Dart 的消息会落到悬浮窗
  /// 引擎(插件的 messenger 是单例,被后启动的悬浮窗引擎覆盖),主界面收不到。
  /// 这里改成主界面主动读取:显示期间定期 [FlutterOverlayWindow.getOverlayPosition],
  /// 位置变化才上报,拖动松手后最多 1 个轮询周期即可落盘。
  void _startPositionPolling() {
    _stopPositionPolling();
    _lastReportedPosition = null;
    _positionPollTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => unawaited(_pollOverlayPosition()),
    );
  }

  void _stopPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
  }

  Future<void> _pollOverlayPosition() async {
    try {
      final position = await FlutterOverlayWindow.getOverlayPosition();
      final current = Offset(position.x, position.y);
      final last = _lastReportedPosition;
      // 亚像素抖动忽略,避免无谓落盘。
      if (last != null && (current - last).distanceSquared < 1.0) {
        return;
      }
      _lastReportedPosition = current;
      _positionController.add(current);
    } on Exception {
      // 悬浮窗已关闭,忽略。
    }
  }

  /// 监听悬浮窗回传的位置,转成逻辑像素流。
  ///
  /// 插件在拖动结束与吸附动画结束时各发一次 `overlay_position`,
  /// 这里只负责转发,持久化由上层决定。
  void _listenOverlayPosition() {
    _overlayMessageSub?.cancel();
    _overlayMessageSub = FlutterOverlayWindow.overlayListener.listen((message) {
      if (message is! Map) return;
      if (message['type'] != 'overlay_position') return;
      final x = message['x'];
      final y = message['y'];
      if (x is num && y is num) {
        _positionController.add(Offset(x.toDouble(), y.toDouble()));
      }
    });
  }

  @override
  Future<bool> setStatusBarEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _statusBarChannel.invokeMethod<bool>(
        'requestPermission',
      );
      if (granted != true) return false;
      _startStatusBarForwarding();
      await _pushStatusBar();
    } else {
      _stopStatusBarForwarding();
      await _statusBarChannel.invokeMethod<void>('setEnabled', false);
    }
    return true;
  }

  @override
  void dispose() {
    _stopPositionPolling();
    _stopOverlayForwarding();
    _stopStatusBarForwarding();
    _overlayMessageSub?.cancel();
    _overlayMessageSub = null;
    _positionController.close();
  }

  void _startOverlayForwarding() {
    _stopOverlayForwarding();
    _overlayReadingsSub = _repository.readings.listen((reading) {
      _lastBpm = reading.bpm;
      _lastStatus = HeartRateConnection.connected;
      _shareOverlayState();
    });
    _overlayConnectionSub = _repository.connection.listen((status) {
      _lastStatus = status;
      if (status != HeartRateConnection.connected) _lastBpm = null;
      _shareOverlayState();
    });
  }

  void _stopOverlayForwarding() {
    _overlayReadingsSub?.cancel();
    _overlayReadingsSub = null;
    _overlayConnectionSub?.cancel();
    _overlayConnectionSub = null;
    for (final timer in _initialOverlayPushTimers) {
      timer.cancel();
    }
    _initialOverlayPushTimers.clear();
  }

  /// 悬浮窗引擎启动需数秒,按固定间隔重试推送直至引擎就绪。
  void _scheduleInitialOverlayPush() {
    for (final delay in _initialOverlayPushDelaysMs) {
      _initialOverlayPushTimers.add(
        Timer(Duration(milliseconds: delay), _shareOverlayState),
      );
    }
  }

  Future<void> _shareOverlayState() async {
    try {
      await FlutterOverlayWindow.shareData({
        'bpm': _lastBpm,
        'status': _lastStatus.name,
        'style': _lastStyle.toJson(),
      });
    } on Exception {
      // 悬浮窗引擎尚未就绪或已关闭,忽略。
    }
  }

  void _startStatusBarForwarding() {
    _stopStatusBarForwarding();
    _lastStatus = _repository.status;
    _lastBpm = _lastStatus == HeartRateConnection.connected
        ? _repository.currentBpm
        : null;
    _statusReadingsSub = _repository.readings.listen((reading) {
      _lastBpm = reading.bpm;
      _lastStatus = HeartRateConnection.connected;
      _pushStatusBar();
    });
    _statusConnectionSub = _repository.connection.listen((status) {
      _lastStatus = status;
      if (status != HeartRateConnection.connected) _lastBpm = null;
      _pushStatusBar();
    });
  }

  void _stopStatusBarForwarding() {
    _statusReadingsSub?.cancel();
    _statusReadingsSub = null;
    _statusConnectionSub?.cancel();
    _statusConnectionSub = null;
  }

  Future<void> _pushStatusBar() async {
    try {
      await _statusBarChannel.invokeMethod<void>('update', {
        'bpm': _lastBpm,
        'status': _lastStatus.name,
      });
    } on PlatformException {
      // 原生端异常(如通知权限被收回),忽略;开关流程会重新请求权限。
    }
  }
}
