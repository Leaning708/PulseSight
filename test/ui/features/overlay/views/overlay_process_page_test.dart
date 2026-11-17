import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/data/services/platform/overlay_ipc.dart';
import 'package:pulse_sight/ui/features/overlay/views/overlay_process_page.dart';
import 'package:pulse_sight/ui/features/overlay/views/overlay_view.dart';

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');
const MethodChannel _screenRetrieverChannel = MethodChannel(
  'dev.leanflutter.plugins/screen_retriever',
);

/// 假的子进程侧链路:可主动注入主进程下发的消息。
class _FakeOverlayLink implements OverlayLink {
  final StreamController<OverlayMessage> _messages =
      StreamController<OverlayMessage>.broadcast();
  final List<OverlayMessage> sent = [];
  final Completer<void> _done = Completer<void>();
  bool closed = false;

  @override
  Stream<OverlayMessage> get messages => _messages.stream;

  @override
  bool get isConnected => !closed;

  @override
  Future<void> get done => _done.future;

  void emit(OverlayMessage message) => _messages.add(message);

  @override
  void send(OverlayMessage message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeOverlayLink link;
  late List<MethodCall> windowCalls;
  late int exitCount;

  setUp(() {
    link = _FakeOverlayLink();
    windowCalls = <MethodCall>[];
    exitCount = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // window_manager 的状态查询在 Dart 侧强解包,必须返回真实取值。
    messenger.setMockMethodCallHandler(_windowManagerChannel, (call) async {
      windowCalls.add(call);
      return switch (call.method) {
        'isFullScreen' ||
        'isMaximized' ||
        'isMinimized' ||
        'isVisible' ||
        'isAlwaysOnTop' => false,
        'getBounds' => <String, dynamic>{
          'x': 0.0,
          'y': 0.0,
          'width': 140.0,
          'height': 170.0,
        },
        'getPosition' => <String, dynamic>{'dx': 100.0, 'dy': 100.0},
        _ => null,
      };
    });
    // window_manager 的 setAlignment 依赖 screen_retriever:必须一起 mock,
    // 否则定位会挂起(生产环境有 3s 超时兜底)。
    messenger.setMockMethodCallHandler(_screenRetrieverChannel, (call) async {
      if (call.method == 'getPrimaryDisplay') {
        return <String, dynamic>{
          'id': 'primary',
          'name': 'Primary',
          'size': <String, dynamic>{'width': 1920.0, 'height': 1080.0},
          'visiblePosition': <String, dynamic>{'dx': 0.0, 'dy': 0.0},
          'visibleSize': <String, dynamic>{'width': 1920.0, 'height': 1040.0},
          'scaleFactor': 1.0,
        };
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_windowManagerChannel, null);
    messenger.setMockMethodCallHandler(_screenRetrieverChannel, null);
  });

  /// 逐帧 pump 直到窗口配置完成。
  ///
  /// 悬浮窗内容含心跳动画,不能 `pumpAndSettle`(永不静止);
  /// 平台通道调用在 mock 下由微任务完成,逐帧推进即可确定性地等到就绪。
  Future<void> settleWindow(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      final state = tester.state<State>(find.byType(OverlayProcessPage));
      if ((state as dynamic).isWindowReady == true) return;
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('等待窗口配置就绪超时;已调用: ${windowCalls.map((c) => c.method).toList()}');
  }

  /// 渲染页面并等待窗口配置完成。
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OverlayProcessPage(link: link, onExit: () async => exitCount++),
      ),
    );
    await tester.pump();
    await settleWindow(tester);
  }

  Future<void> deliver(WidgetTester tester, OverlayMessage message) async {
    link.emit(message);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  Iterable<MethodCall> callsTo(String method) =>
      windowCalls.where((call) => call.method == method);

  testWidgets('初始化窗口:无边框、置顶、隐藏任务栏、启动保持隐藏', (tester) async {
    await pumpPage(tester);

    expect(callsTo('setAsFrameless'), isNotEmpty);
    expect(callsTo('setAlwaysOnTop'), isNotEmpty);
    // macOS 没有任务栏概念,且调用 setSkipTaskbar 会让整个应用变为
    // accessory(见 macOS 平台陷阱),因此只在 Windows 断言该调用。
    if (Platform.isMacOS) {
      expect(callsTo('setSkipTaskbar'), isEmpty);
    } else {
      expect(callsTo('setSkipTaskbar'), isNotEmpty);
    }
    // 启动阶段仅置隐藏,等主进程下发 show 再显示。
    expect(callsTo('show'), isEmpty);
    expect(callsTo('hide'), isNotEmpty);
    // 就绪后回传 ready,便于主进程补发状态。
    expect(link.sent.map((m) => m['type']), contains(OverlayMessageType.ready));
  });

  testWidgets('收到 state 后渲染心率与样式并调整窗口尺寸', (tester) async {
    await pumpPage(tester);
    windowCalls.clear();

    await deliver(tester, {
      'type': OverlayMessageType.state,
      'bpm': 73,
      'status': 'connected',
      'style': <String, Object?>{
        'backgroundWidth': 180.0,
        'backgroundHeight': 240.0,
      },
    });

    final view = tester.widget<OverlayView>(find.byType(OverlayView));
    expect(view.bpm, 73);
    expect(view.connected, isTrue);
    expect(view.style.backgroundWidth, 180);
    expect(
      callsTo('setBounds').map((call) => call.arguments),
      contains(
        predicate((Object? args) => args is Map && args['width'] == 180.0),
      ),
    );
  });

  testWidgets('相同样式尺寸不重复调整窗口', (tester) async {
    await pumpPage(tester);
    const style = <String, Object?>{
      'backgroundWidth': 150.0,
      'backgroundHeight': 200.0,
    };
    await deliver(tester, {
      'type': OverlayMessageType.state,
      'bpm': 70,
      'status': 'connected',
      'style': style,
    });
    windowCalls.clear();

    await deliver(tester, {
      'type': OverlayMessageType.state,
      'bpm': 71,
      'status': 'connected',
      'style': style,
    });

    expect(callsTo('setBounds'), isEmpty, reason: '尺寸未变不应重复调整');
  });

  testWidgets('passthrough 只在取值变化时下发穿透', (tester) async {
    await pumpPage(tester);
    windowCalls.clear();

    await deliver(tester, {
      'type': OverlayMessageType.passthrough,
      'value': true,
    });
    await deliver(tester, {
      'type': OverlayMessageType.passthrough,
      'value': true,
    });

    expect(callsTo('setIgnoreMouseEvents'), hasLength(1));
    expect(
      callsTo('setIgnoreMouseEvents').single.arguments,
      containsPair('ignore', true),
    );
  });

  testWidgets('show / hide 控制窗口显隐', (tester) async {
    await pumpPage(tester);
    windowCalls.clear();

    await deliver(tester, {'type': OverlayMessageType.show});
    expect(callsTo('show'), hasLength(1));

    await deliver(tester, {'type': OverlayMessageType.hide});
    expect(callsTo('hide'), hasLength(1));
  });

  testWidgets('窗口就绪前的 show 请求会被缓存并在就绪后执行', (tester) async {
    // 先不等待就绪就投递 show(模拟主进程抢先下发)。
    await tester.pumpWidget(
      MaterialApp(
        home: OverlayProcessPage(link: link, onExit: () async => exitCount++),
      ),
    );
    link.emit({'type': OverlayMessageType.show});
    await tester.pump();

    await tester.pump();
    await settleWindow(tester);

    expect(callsTo('show'), hasLength(1), reason: '缓存请求应在就绪后补执行');
  });

  testWidgets('quit 触发退出回调', (tester) async {
    await pumpPage(tester);

    await deliver(tester, {'type': OverlayMessageType.quit});

    expect(exitCount, 1);
  });
}
