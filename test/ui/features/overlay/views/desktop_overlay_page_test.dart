import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/ui/features/overlay/views/desktop_overlay_page.dart';
import 'package:pulse_sight/ui/features/overlay/views/overlay_view.dart';

const MethodChannel _multiWindowChannel = MethodChannel(
  'mixin.one/desktop_multi_window',
);
// desktop_multi_window 在 Dart 侧给该通道装了 handler,只能用二进制层
// mock 才能截获其收发。
const String _channelsChannelName = 'mixin.one/desktop_multi_window/channels';
const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

/// 记录 window_manager 收到的原生调用。
class _WindowManagerRecorder {
  final List<MethodCall> calls = [];

  /// 尺寸调整请求:window_manager 在 Windows 上经 `setBounds` 下发尺寸。
  List<Size> get sizes => [
    for (final call in calls)
      if (call.method == 'setSize' || call.method == 'setBounds')
        if (call.arguments case final Map<dynamic, dynamic> args)
          if (args['width'] case final num width)
            if (args['height'] case final num height)
              Size(width.toDouble(), height.toDouble()),
  ];

  Iterable<MethodCall> byMethod(String method) =>
      calls.where((call) => call.method == method);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _WindowManagerRecorder recorder;

  setUp(() {
    recorder = _WindowManagerRecorder();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // 副窗口引擎的原生通道:窗口定义查询。
    messenger.setMockMethodCallHandler(_multiWindowChannel, (call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, dynamic>{
          'windowId': 'overlay-window',
          'windowArgument': 'overlay',
        };
      }
      return null;
    });
    // 跨窗口通道注册请求由测试替身应答(见 deliverCrossWindowCall)。
    messenger.setMockMessageHandler(_channelsChannelName, (message) async {
      return const StandardMethodCodec().encodeSuccessEnvelope(true);
    });
    messenger.setMockMethodCallHandler(_windowManagerChannel, (call) async {
      recorder.calls.add(call);
      // window_manager 的窗口状态查询在 Dart 侧强解包 bool。
      return switch (call.method) {
        'isFullScreen' ||
        'isMaximized' ||
        'isMinimized' ||
        'isVisible' ||
        'isAlwaysOnTop' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_multiWindowChannel, null);
    messenger.setMockMessageHandler(_channelsChannelName, null);
    messenger.setMockMethodCallHandler(_windowManagerChannel, null);
  });

  /// 渲染悬浮窗页面,并等待跨窗口处理器注册完成。
  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DesktopOverlayPage()));
    await tester.runAsync(() async {
      final state = tester.state<State>(find.byType(DesktopOverlayPage));
      await (state as dynamic).handlerReady;
    });
    await tester.pump();
  }

  /// 复现主窗口 `WindowController.invokeMethod` 的转发结果:平台把调用
  /// 投递到副窗口的 `WindowMethodChannel` 并交给该页面登记的处理器。
  Future<void> deliverCrossWindowCall(
    WidgetTester tester,
    String method,
    Object? arguments,
  ) async {
    final controller = await WindowController.fromCurrentEngine();
    await tester.runAsync(() async {
      final state = tester.state<State>(find.byType(DesktopOverlayPage));
      await (state as dynamic).handleCrossWindowCall(
        'mixin.one/window_controller/${controller.windowId}',
        MethodCall(method, arguments),
      );
    });
  }

  Map<String, dynamic> updateArgs(double width, double height) => {
    'bpm': 72,
    'status': 'connected',
    'style': <String, dynamic>{
      'backgroundWidth': width,
      'backgroundHeight': height,
    },
  };

  testWidgets('update 推送只更新悬浮窗内容与尺寸', (tester) async {
    await pumpOverlay(tester);
    recorder.calls.clear();

    // 与主窗口 DesktopOverlayService 推送的参数格式一致。
    await deliverCrossWindowCall(tester, 'update', updateArgs(180, 240));
    await deliverCrossWindowCall(tester, 'update', updateArgs(200, 240));
    // 相同尺寸重复推送不应再次调整窗口。
    await deliverCrossWindowCall(tester, 'update', updateArgs(200, 240));
    await tester.pump();

    // 回归点 1:每个 case 必须 break。旧实现 `update` 处理完继续落到
    // `setPassthrough`,对 Map 强转 bool 抛 TypeError;副窗口引擎无 zone
    // 守护,异常直达进程入口所在的 UI 线程 → 整个应用闪退。
    expect(tester.takeException(), isNull);
    expect(recorder.sizes, [const Size(180, 240), const Size(200, 240)]);
    expect(
      recorder.byMethod('setIgnoreMouseEvents'),
      isEmpty,
      reason: '数据推送不应改动鼠标穿透',
    );
    // 回归点 2:样式必须真正驱动悬浮窗内容(此前 update 被打断,
    // 悬浮窗停留在未连接状态)。
    final view = tester.widget<OverlayView>(find.byType(OverlayView));
    expect(view.bpm, 72);
    expect(view.connected, isTrue);
    expect(view.style.backgroundWidth, 200);
  });

  testWidgets('setPassthrough 仅在取值变化时下发穿透', (tester) async {
    await pumpOverlay(tester);
    recorder.calls.clear();

    await deliverCrossWindowCall(tester, 'update', updateArgs(180, 240));
    await deliverCrossWindowCall(tester, 'setPassthrough', true);
    await deliverCrossWindowCall(tester, 'setPassthrough', true);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(recorder.sizes, [const Size(180, 240)], reason: '穿透开关不应调整窗口尺寸');
    expect(
      recorder.byMethod('setIgnoreMouseEvents'),
      hasLength(1),
      reason: '相同穿透取值不应重复下发',
    );
  });
}
