import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/services/simulated_heart_rate_source.dart';
import 'package:pulse_sight/data/services/switchable_heart_rate_source.dart';
import 'package:pulse_sight/domain/models/heart_rate_connection.dart';
import 'package:pulse_sight/domain/models/heart_rate_device.dart';
import 'package:pulse_sight/domain/models/heart_rate_mode.dart';
import 'package:pulse_sight/domain/models/heart_rate_scenario.dart';

import 'real_heart_rate_source_fake.dart';

const _band = HeartRateDevice(
  id: 'band-1',
  name: 'Xiaomi Smart Band 10',
  advertisesHeartRate: true,
);

void main() {
  late FakeRealHeartRateSource real;
  late SimulatedHeartRateSource simulated;
  late SwitchableHeartRateSource source;

  setUp(() {
    real = FakeRealHeartRateSource();
    simulated = SimulatedHeartRateSource(
      connectDelay: Duration.zero,
      sampleInterval: const Duration(hours: 1),
    );
    source = SwitchableHeartRateSource(
      real: real,
      simulated: simulated,
      mode: HeartRateMode.real,
    );
  });

  tearDown(() => source.dispose());

  test('真实模式使用真实数据源,模拟数据不转发', () async {
    await source.connectTo(_band);
    await pumpEventQueue();

    expect(source.mode, HeartRateMode.real);
    expect(source.status, HeartRateConnection.connected);
    expect(source.currentBpm, 80);
    expect(source.connectedDevice, _band);

    real.emitBpm(81);
    await pumpEventQueue();
    expect(source.currentBpm, 81);
  });

  test('切换到模拟模式会断开真实设备且互斥', () async {
    await source.connectTo(_band);
    await pumpEventQueue();

    await source.setMode(HeartRateMode.simulated);

    expect(real.calls, contains('disconnect'));
    expect(source.mode, HeartRateMode.simulated);
    expect(source.status, HeartRateConnection.disconnected);
    expect(source.connectedDevice, isNull);

    // 真实源在切换后继续推数据也必须被忽略。
    real.emitBpm(120);
    await pumpEventQueue();
    expect(source.currentBpm, isNull);

    await source.connect();
    await pumpEventQueue();

    expect(source.status, HeartRateConnection.connected);
    expect(source.currentBpm, isNotNull);
  });

  test('模拟模式下扫描与指定连接为空操作', () async {
    await source.setMode(HeartRateMode.simulated);
    final callCount = real.calls.length;

    await source.startScan();
    await source.connectTo(_band);

    expect(real.calls.length, callCount);
    expect(source.status, HeartRateConnection.disconnected);
  });

  test('切回真实模式会断开模拟并恢复扫描能力', () async {
    await source.setMode(HeartRateMode.simulated);
    await source.connect();
    await pumpEventQueue();
    expect(source.status, HeartRateConnection.connected);

    await source.setMode(HeartRateMode.real);

    expect(simulated.status, HeartRateConnection.disconnected);
    expect(source.status, HeartRateConnection.disconnected);
    expect(source.mode, HeartRateMode.real);

    await source.startScan();
    expect(real.calls, contains('startScan'));
  });

  test('模拟场景设置转发给模拟源', () {
    source.setScenario(HeartRateScenario.high);

    expect(source.scenario, HeartRateScenario.high);
    expect(simulated.scenario, HeartRateScenario.high);
  });

  test('modeStream 先给出当前模式,再推送切换结果', () async {
    final modes = <HeartRateMode>[];
    final subscription = source.modeStream.listen(modes.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await source.setMode(HeartRateMode.simulated);
    await pumpEventQueue();

    expect(modes.first, HeartRateMode.real);
    expect(modes.last, HeartRateMode.simulated);
  });
}
