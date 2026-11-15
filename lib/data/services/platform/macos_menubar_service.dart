import 'dart:async';

import 'package:flutter/services.dart';

import '../../../domain/models/heart_rate_connection.dart';
import '../../../domain/models/heart_rate_reading.dart';
import '../../repositories/heart_rate_repository.dart';

/// macOS 菜单栏显示接口,便于 ViewModel 测试时替换。
abstract interface class MenubarDisplay {
  /// 开关菜单栏心率显示。
  Future<void> setEnabled(bool enabled);

  /// 释放资源。
  void dispose();
}

/// macOS 顶部菜单栏心率显示服务。
///
/// 通过原生端([MainFlutterWindow.swift])注册的 `pulsesight/menubar`
/// MethodChannel 更新 NSStatusItem 标题。
class MacosMenubarService implements MenubarDisplay {
  /// 创建服务;[repository] 为心率数据来源。
  MacosMenubarService({required this._repository});

  final HeartRateRepository _repository;

  static const MethodChannel _channel = MethodChannel('pulsesight/menubar');

  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;

  int? _lastBpm;
  bool _lastConnected = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      _lastConnected = _repository.status == HeartRateConnection.connected;
      _lastBpm = _lastConnected ? _repository.currentBpm : null;
      _startForwarding();
      await _push();
      await _channel.invokeMethod<void>('setVisible', true);
    } else {
      _stopForwarding();
      await _channel.invokeMethod<void>('setVisible', false);
    }
  }

  @override
  void dispose() {
    _stopForwarding();
  }

  void _startForwarding() {
    _stopForwarding();
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
  }

  Future<void> _push() async {
    try {
      await _channel.invokeMethod<void>('update', {
        'bpm': _lastBpm,
        'connected': _lastConnected,
      });
    } on MissingPluginException {
      // 原生端尚未注册(非 macOS 或窗口未就绪),忽略。
    }
  }
}
