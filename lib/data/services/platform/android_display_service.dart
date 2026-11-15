import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

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
  Future<void> showOverlay();

  /// 关闭心率悬浮窗。
  Future<void> hideOverlay();

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

  static const MethodChannel _statusBarChannel = MethodChannel(
    'pulsesight/status_bar',
  );

  /// 悬浮窗尺寸(逻辑像素)。
  static const Size overlaySize = Size(130, 170);

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
  Future<void> showOverlay() async {
    // showOverlay 的尺寸单位是物理像素,需按主窗口 DPR 从逻辑像素换算。
    final dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;
    final widthPx = (overlaySize.width * dpr).round();
    final heightPx = (overlaySize.height * dpr).round();
    await FlutterOverlayWindow.showOverlay(
      height: heightPx,
      width: widthPx,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'PulseSight 心率悬浮窗',
      visibility: NotificationVisibility.visibilitySecret,
    );
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
    _stopOverlayForwarding();
    await FlutterOverlayWindow.closeOverlay();
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
    _stopOverlayForwarding();
    _stopStatusBarForwarding();
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
