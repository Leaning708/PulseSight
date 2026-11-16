import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/data/services/platform/overlay_ipc.dart';
import 'package:pulse_sight/data/services/platform/windows_overlay_process_service.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';

import 'home_fakes.dart';

void main() {
  late HeartRateRepository repository;
  late FakeHeartRateSource source;
  late FakeOverlayHost host;
  late WindowsOverlayProcessService service;

  setUp(() {
    source = FakeHeartRateSource();
    repository = HeartRateRepository(source: source);
    host = FakeOverlayHost();
    service = WindowsOverlayProcessService(
      repository: repository,
      linkFactory: () => host,
      executablePath: 'pulse_sight.exe',
    );
  });

  tearDown(() {
    service.dispose();
    repository.dispose();
  });

  test('show 时拉起子进程并下发显示、穿透与首帧状态', () async {
    await service.show(passthrough: true);

    expect(host.started, hasLength(1));
    expect(host.started.single, 'pulse_sight.exe');
    final types = host.sent.map((m) => m['type']).toList();
    expect(types, contains(OverlayMessageType.show));
    expect(
      host.sent.firstWhere((m) => m['type'] == OverlayMessageType.passthrough),
      containsPair('value', true),
    );
    final state = host.sent.firstWhere(
      (m) => m['type'] == OverlayMessageType.state,
    );
    expect(state['bpm'], isNull);
    expect(state['status'], HeartRateConnection.disconnected.name);
    expect(state['style'], isA<Map<String, Object?>>());
  });

  test('子进程就绪(ready)后补发显示与最新状态', () async {
    await service.show(passthrough: false);
    host.sent.clear();

    // 模拟子进程窗口就绪。
    host.emit({'type': OverlayMessageType.ready});
    await Future<void>.delayed(Duration.zero);

    final types = host.sent.map((m) => m['type']).toList();
    expect(types.first, OverlayMessageType.show);
    expect(types, contains(OverlayMessageType.state));
  });

  test('心率读数变化时推送状态快照', () async {
    await service.show(passthrough: false);
    host.sent.clear();

    source.emitBpm(78, status: HeartRateConnection.connected);
    await Future<void>.delayed(Duration.zero);

    final states = host.sent
        .where((m) => m['type'] == OverlayMessageType.state)
        .toList();
    expect(states, isNotEmpty);
    expect(states.last['bpm'], 78);
    expect(states.last['status'], 'connected');
  });

  test('样式变化推送一次且相同样式不重复推送', () async {
    await service.show(passthrough: false);
    host.sent.clear();

    await service.setStyle(const OverlayStyle(heartSize: 80));
    await service.setStyle(const OverlayStyle(heartSize: 80));

    final states = host.sent
        .where((m) => m['type'] == OverlayMessageType.state)
        .toList();
    expect(states, hasLength(1));
    expect((states.single['style'] as Map)['heartSize'], 80);
  });

  test('hide 下发隐藏且停止转发心率', () async {
    await service.show(passthrough: false);
    await service.hide();
    host.sent.clear();

    source.emitBpm(90, status: HeartRateConnection.connected);
    await Future<void>.delayed(Duration.zero);

    expect(host.sent, isEmpty, reason: '隐藏后不再推送心率');
    expect(
      host.sent.where((m) => m['type'] == OverlayMessageType.hide),
      isEmpty,
    );
  });

  test('setPassthrough 只在取值变化时下发', () async {
    await service.show(passthrough: false);
    host.sent.clear();

    await service.setPassthrough(true);
    await service.setPassthrough(true);

    expect(
      host.sent.where((m) => m['type'] == OverlayMessageType.passthrough),
      hasLength(1),
    );
  });

  test('子进程再次显示时复用同一链路(不重复拉起)', () async {
    await service.show(passthrough: false);
    await service.hide();
    await service.show(passthrough: false);

    expect(host.started, hasLength(1));
  });

  test('子进程启动失败后按退避重试并最终放弃', () async {
    host.startResult = false;

    await service.show(passthrough: false);
    await service.show(passthrough: false);
    await service.show(passthrough: false);
    await service.show(passthrough: false);

    // 三次退避重试后熔断,不再无休止拉起进程。
    expect(host.started.length, 3);
  });

  test('dispose 关闭链路以回收子进程', () async {
    await service.show(passthrough: false);
    service.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(host.closed, isTrue);
  });
}
