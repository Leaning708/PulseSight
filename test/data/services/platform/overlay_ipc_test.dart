import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/platform/overlay_ipc.dart';

void main() {
  group('overlayProcessPort', () {
    test('非子进程返回 null', () {
      expect(overlayProcessPort(const []), isNull);
      expect(overlayProcessPort(const ['--port=1']), isNull);
      expect(overlayProcessPort(const ['some', 'args']), isNull);
    });

    test('解析子进程端口', () {
      expect(
        overlayProcessPort(const [
          OverlayProcessArgs.flag,
          '--overlay-port=41234',
        ]),
        41234,
      );
      // 参数顺序无关。
      expect(
        overlayProcessPort(const [
          '--overlay-port=9000',
          OverlayProcessArgs.flag,
        ]),
        9000,
      );
    });

    test('端口非法时返回 null(视为普通启动)', () {
      expect(
        overlayProcessPort(const [
          OverlayProcessArgs.flag,
          '--overlay-port=abc',
        ]),
        isNull,
      );
      expect(
        overlayProcessPort(const [OverlayProcessArgs.flag, '--overlay-port=']),
        isNull,
      );
      // 缺少 port 参数时不得误判为子进程。
      expect(overlayProcessPort(const [OverlayProcessArgs.flag]), isNull);
    });
  });

  group('JsonLineLink', () {
    late ServerSocket server;
    late JsonLineLink hostLink;
    late JsonLineLink clientLink;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first;
      final client = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      hostLink = JsonLineLink(await accepted);
      clientLink = JsonLineLink(client);
    });

    tearDown(() async {
      await hostLink.close();
      await clientLink.close();
      await server.close();
    });

    test('按换行分帧投递多条消息', () async {
      final received = <OverlayMessage>[];
      hostLink.messages.listen(received.add);

      clientLink.send({'type': 'show'});
      clientLink.send({'type': 'state', 'bpm': 72});
      await _until(() => received.length >= 2);

      expect(received, [
        {'type': 'show'},
        {'type': 'state', 'bpm': 72},
      ]);
    });

    test('半行数据会被缓冲到下一个数据块', () async {
      final received = <OverlayMessage>[];
      hostLink.messages.listen(received.add);

      final socket = await _socketOf(clientLink);
      socket.write('{"type":"pa');
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(received, isEmpty, reason: '未遇到换行前不应投递');

      socket.write('ssthrough","value":true}\n');
      await socket.flush();
      await _until(() => received.isNotEmpty);

      expect(received.single, {'type': 'passthrough', 'value': true});
    });

    test('非法 JSON 被丢弃且不影响后续消息', () async {
      final received = <OverlayMessage>[];
      hostLink.messages.listen(received.add);

      final socket = await _socketOf(clientLink);
      socket.write('not-json\n');
      socket.write('${jsonEncode({'type': 'hide'})}\n');
      await socket.flush();
      await _until(() => received.isNotEmpty);

      expect(received.single, {'type': 'hide'});
    });

    test('关闭后 isConnected 为 false 且 done 完成', () async {
      expect(clientLink.isConnected, isTrue);
      await clientLink.close();
      expect(clientLink.isConnected, isFalse);
      await clientLink.done.timeout(const Duration(seconds: 2));
    });

    test('关闭后发送被静默丢弃', () async {
      await clientLink.close();
      // 不抛异常即为通过。
      clientLink.send({'type': 'quit'});
    });
  });
}

/// 取链路内部的 socket 以写入原始数据(验证分帧实现)。
Future<Socket> _socketOf(JsonLineLink link) async => link.debugSocket;

/// 轮询等待条件成立(避免依赖固定 sleep)。
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('等待超时');
}
