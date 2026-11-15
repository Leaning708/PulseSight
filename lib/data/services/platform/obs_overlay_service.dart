import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../domain/models/heart_rate_connection.dart';
import '../../../domain/models/heart_rate_history.dart';
import '../../../domain/models/heart_rate_reading.dart';
import '../../../domain/models/overlay_style.dart';
import '../../repositories/heart_rate_repository.dart';
import 'obs_overlay_page.dart';

/// OBS 浏览器源显示端。
///
/// 在本机回环地址上启动 HTTP 服务,提供叠加页与 WebSocket 数据通道:
/// OBS 添加浏览器源指向 [overlayUrl],页面即被合成进录制/推流画面,
/// 桌面上不显示任何窗口。
abstract interface class ObsOverlayDisplay {
  /// 启用/停用本地服务;返回 false 表示启动失败(如端口被占用),
  /// 此时不改变任何状态(调用方据此提示,且不应持久化开关)。
  Future<bool> setEnabled(bool enabled);

  /// 浏览器源地址(如 http://127.0.0.1:9423/)。
  String get overlayUrl;

  /// 推送当前悬浮窗样式到所有已连接的浏览器源。
  Future<void> setStyle(OverlayStyle style);

  /// 释放资源,释放后不可再使用。
  void dispose();
}

/// 基于 dart:io 的 [ObsOverlayDisplay] 实现,零第三方依赖。
///
/// 与其它显示端服务一致:构造时注入 [HeartRateRepository],
/// 启用后订阅 readings/connection 并缓存最近状态,任一变化即广播;
/// 页面快照在 WebSocket 连接建立时主动推送,断线由页面端自动重连。
class ObsOverlayService implements ObsOverlayDisplay {
  /// 创建服务;[requestedPort] 默认 [defaultPort],测试可传 0 由系统分配临时端口。
  ObsOverlayService({
    required this._repository,
    this._requestedPort = defaultPort,
  });

  /// 默认监听端口(仅回环地址,不暴露局域网)。
  static const int defaultPort = 9423;

  final HeartRateRepository _repository;
  final int _requestedPort;

  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  StreamSubscription<HeartRateReading>? _readingsSub;
  StreamSubscription<HeartRateConnection>? _connectionSub;

  bool _enabled = false;

  int? _lastBpm;
  HeartRateConnection _lastStatus = HeartRateConnection.disconnected;
  OverlayStyle _lastStyle = OverlayStyle.defaults;
  final HeartRateHistory _history = HeartRateHistory();

  /// 实际监听端口(未启用时为请求端口;注入 0 时由系统分配)。
  int get port => _server?.port ?? _requestedPort;

  @override
  String get overlayUrl => 'http://127.0.0.1:$port/';

  @override
  Future<bool> setEnabled(bool enabled) async {
    if (_enabled == enabled) return true;
    if (enabled) {
      final HttpServer server;
      try {
        server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          _requestedPort,
        );
      } on SocketException {
        // 端口被占用等:保持原状态,由调用方提示。
        return false;
      }
      _server = server;
      server.listen(_onRequest, cancelOnError: false);
      // 种子值与其它显示端一致:启用瞬间取仓库当前快照。
      _lastBpm = _repository.currentBpm;
      _lastStatus = _repository.status;
      _history.maxLength = _lastStyle.chartSampleCount;
      _history.trim();
      _startForwarding();
      _enabled = true;
      _broadcast();
      return true;
    }
    _shutdown();
    return true;
  }

  @override
  Future<void> setStyle(OverlayStyle style) async {
    if (_lastStyle == style) return;
    _lastStyle = style;
    _history.maxLength = style.chartSampleCount;
    _history.trim();
    _broadcast();
  }

  @override
  void dispose() {
    _shutdown();
  }

  // ---- 请求路由 ----

  void _onRequest(HttpRequest request) {
    switch (request.uri.path) {
      case '/' || '/overlay':
        _servePage(request);
      case '/ws':
        unawaited(_upgradeWebSocket(request));
      default:
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close());
    }
  }

  void _servePage(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('text', 'html', charset: 'utf-8');
    request.response.write(obsOverlayHtml);
    unawaited(request.response.close());
  }

  Future<void> _upgradeWebSocket(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      socket.listen(
        (_) {}, // 客户端仅保活,消息一律忽略。
        onDone: () => _clients.remove(socket),
        onError: (_) => _clients.remove(socket),
        cancelOnError: true,
      );
      // 连接建立即推当前快照,页面无需等待下一次采样。
      socket.add(jsonEncode(_snapshot()));
    } on WebSocketException {
      request.response.statusCode = HttpStatus.badRequest;
      unawaited(request.response.close());
    }
  }

  // ---- 数据转发与广播 ----

  void _startForwarding() {
    _readingsSub = _repository.readings.listen((reading) {
      _lastBpm = reading.bpm;
      _history.add(reading.bpm);
      _broadcast();
    });
    _connectionSub = _repository.connection.listen((status) {
      _lastStatus = status;
      if (status != HeartRateConnection.connected) {
        _history.clear();
      }
      _broadcast();
    });
  }

  void _stopForwarding() {
    _readingsSub?.cancel();
    _readingsSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
  }

  Map<String, Object?> _snapshot() => {
    'type': 'state',
    'status': _lastStatus.name,
    'bpm': _lastBpm,
    'style': _lastStyle.toJson(),
    'history': _history.values,
  };

  void _broadcast() {
    if (_clients.isEmpty) return;
    final message = jsonEncode(_snapshot());
    for (final client in _clients.toList()) {
      try {
        client.add(message);
      } on StateError {
        _clients.remove(client);
      }
    }
  }

  // ---- 停用/释放 ----

  void _shutdown() {
    _stopForwarding();
    for (final client in _clients.toList()) {
      unawaited(client.close());
    }
    _clients.clear();
    unawaited(_server?.close(force: true));
    _server = null;
    _enabled = false;
  }
}
