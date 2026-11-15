import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/services/heart_rate_source.dart';
import 'package:pulse_sight/data/services/platform/obs_overlay_service.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';

/// 手动控制状态与数据的心率源 Fake(仅本文件使用的最小实现)。
class _FakeHeartRateSource implements HeartRateSource {
  final StreamController<int> _bpmController =
      StreamController<int>.broadcast();
  final StreamController<HeartRateConnection> _connectionController =
      StreamController<HeartRateConnection>.broadcast();

  @override
  HeartRateConnection status = HeartRateConnection.disconnected;

  @override
  int? currentBpm;

  @override
  Stream<int> get bpmStream => _bpmController.stream;

  @override
  Stream<HeartRateConnection> get connectionStream =>
      _connectionController.stream;

  @override
  Future<void> connect() async {
    status = HeartRateConnection.connected;
    _connectionController.add(status);
    emitReading(75);
  }

  @override
  Future<void> disconnect() async {
    status = HeartRateConnection.disconnected;
    currentBpm = null;
    _connectionController.add(status);
  }

  void emitReading(int bpm) {
    currentBpm = bpm;
    _bpmController.add(bpm);
  }

  @override
  void dispose() {
    _bpmController.close();
    _connectionController.close();
  }
}

/// 轮询等待异步条件成立(真实回环 IO 无固定时序)。
Future<void> pumpUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: '等待条件超时');
}

void main() {
  group('ObsOverlayService', () {
    late _FakeHeartRateSource source;
    late HeartRateRepository repository;
    late ObsOverlayService service;

    setUp(() {
      source = _FakeHeartRateSource();
      repository = HeartRateRepository(source: source);
      // port 0:由系统分配临时端口,避免与其他测试/服务冲突。
      service = ObsOverlayService(repository: repository, requestedPort: 0);
    });

    tearDown(() {
      service.dispose();
      repository.dispose();
    });

    test('启用后监听实际端口并提供 overlayUrl', () async {
      final ok = await service.setEnabled(true);

      expect(ok, isTrue);
      expect(service.port, isNot(0));
      expect(service.overlayUrl, 'http://127.0.0.1:${service.port}/');
    });

    test('重复启用返回 true 且不重复监听', () async {
      await service.setEnabled(true);
      final port = service.port;

      expect(await service.setEnabled(true), isTrue);
      expect(service.port, port, reason: '已启用时不应重新绑定端口');
    });

    test('GET / 返回 HTML 叠加页', () async {
      await service.setEnabled(true);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(service.overlayUrl));
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/html');
      final body = await response.transform(utf8.decoder).join();
      expect(body, contains('<html'));
      expect(body, contains('/ws'));
      client.close();
    });

    test('未知路径返回 404', () async {
      await service.setEnabled(true);
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${service.port}/nope'),
      );
      final response = await request.close();

      expect(response.statusCode, HttpStatus.notFound);
      client.close();
    });

    test('WS 连接即收到快照,bpm/状态变化持续广播', () async {
      await service.setEnabled(true);
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${service.port}/ws',
      );
      final messages = <Map<String, Object?>>[];
      socket.listen((data) {
        messages.add(jsonDecode(data as String) as Map<String, Object?>);
      });

      // 快照:初始未连接、样式为默认、历史为空。
      await pumpUntil(() => messages.isNotEmpty);
      final snapshot = messages.first;
      expect(snapshot['type'], 'state');
      expect(snapshot['status'], 'disconnected');
      expect(snapshot['bpm'], isNull);
      expect((snapshot['style'] as Map), isNotEmpty);
      expect(snapshot['history'], isEmpty);

      // 连接:状态广播 + 采样广播(75),历史开始累积。
      await source.connect();
      await pumpUntil(
        () => messages.any((m) => m['bpm'] == 75 && m['status'] == 'connected'),
      );

      // 断开:状态回 disconnected,历史清空。
      await source.disconnect();
      await pumpUntil(
        () => messages.any(
          (m) =>
              m['status'] == 'disconnected' && (m['history'] as List).isEmpty,
        ),
      );
      await socket.close();
    });

    test('setStyle 广播新样式', () async {
      await service.setEnabled(true);
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${service.port}/ws',
      );
      final messages = <Map<String, Object?>>[];
      socket.listen((data) {
        messages.add(jsonDecode(data as String) as Map<String, Object?>);
      });
      await pumpUntil(() => messages.isNotEmpty);
      messages.clear();

      await service.setStyle(const OverlayStyle(heartSize: 96));

      await pumpUntil(() => messages.isNotEmpty);
      final style = messages.last['style'] as Map;
      expect(style['heartSize'], 96.0);
      await socket.close();
    });

    test('停用后连接关闭且可重新启用', () async {
      await service.setEnabled(true);
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${service.port}/ws',
      );
      final closed = Completer<void>();
      socket.listen((_) {}, onDone: closed.complete, onError: (_) {});
      await service.setEnabled(false);
      await pumpUntil(() => closed.isCompleted);

      // 重新启用:port 0 会再次分配端口,服务恢复可用。
      expect(await service.setEnabled(true), isTrue);
      final socket2 = await WebSocket.connect(
        'ws://127.0.0.1:${service.port}/ws',
      );
      final gotSnapshot = Completer<void>();
      socket2.listen((_) => gotSnapshot.complete());
      await pumpUntil(() => gotSnapshot.isCompleted);
      await socket2.close();
    });

    test('dispose 幂等且关闭服务器', () async {
      await service.setEnabled(true);
      service.dispose();
      service.dispose(); // 二次调用不应抛异常

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${service.port}/'),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 1),
        );
        // 服务器已关闭:正常不应到达这里;若到达则视为失败。
        fail('服务器已停用但仍响应: ${response.statusCode}');
      } on Exception {
        // 预期:连接被拒/超时。
      } finally {
        client.close();
      }
    });
  });
}
