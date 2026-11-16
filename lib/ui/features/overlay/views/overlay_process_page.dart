import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../data/services/platform/overlay_ipc.dart';
import '../../../../domain/models/overlay_style.dart';
import 'overlay_view.dart';
import '../view_models/overlay_view_model.dart';

/// 悬浮窗**子进程**页面(仅 Windows 使用)。
///
/// 该进程由主进程以 `--overlay-process --overlay-port=<port>` 拉起,只负责
/// 绘制悬浮窗并与主进程通信:
/// - 窗口:无边框、置顶、跳过任务栏、右下角初始位置;启动即隐藏,
///   收到 `show` 后再显示,避免闪烁;
/// - 数据:接收 `state`(bpm / 连接状态 / 样式)驱动 [OverlayView];
/// - 交互:`passthrough` 切换鼠标穿透,`hide` 隐藏窗口,`quit` 直接退出。
///
/// 之所以独立成进程,是为规避 Flutter Windows 嵌入层不支持单进程多引擎的
/// 限制,详见 `WindowsOverlayProcessService` 与 `docs/troubleshooting.md` §10。
class OverlayProcessPage extends StatefulWidget {
  /// 创建悬浮窗子进程页面;[link] 为与主进程的通信链路。
  ///
  /// [onExit] 仅供测试注入,生产环境退出整个子进程。
  const OverlayProcessPage({super.key, required this.link, this.onExit});

  /// 与主进程的通信链路(已连接)。
  final OverlayLink link;

  /// 退出子进程的回调(测试用)。
  final Future<void> Function()? onExit;

  @override
  State<OverlayProcessPage> createState() => _OverlayProcessPageState();
}

class _OverlayProcessPageState extends State<OverlayProcessPage> {
  final OverlayViewModel _viewModel = OverlayViewModel();

  /// 悬浮窗初始尺寸(逻辑像素);实际尺寸随后由样式驱动。
  static const Size initialWindowSize = Size(140, 170);

  /// 右下角留白,与 macOS 悬浮窗保持一致。
  static const Offset bottomRightMargin = Offset(16, 12);

  StreamSubscription<OverlayMessage>? _sub;
  bool _passthrough = false;
  bool _windowReady = false;
  Size? _lastWindowSize;

  /// 最近一次显隐请求;窗口就绪前收到时先缓存,就绪后补执行。
  bool? _pendingVisible;

  /// 窗口配置完成信号(测试用于确定性等待)。
  final Completer<void> _ready = Completer<void>();

  /// 窗口是否已完成配置(测试与调试使用)。
  bool get isWindowReady => _windowReady;

  /// 窗口配置完成(测试与调试使用)。
  Future<void> get windowReady => _ready.future;

  @override
  void initState() {
    super.initState();
    _sub = widget.link.messages.listen(_onMessage);
    unawaited(_init());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: initialWindowSize,
        backgroundColor: Colors.transparent,
        alwaysOnTop: true,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.setAsFrameless();
        await windowManager.setSize(initialWindowSize);
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setAlwaysOnTop(true);
        if (!Platform.isMacOS) {
          // 仅 Windows 需要隐藏任务栏项;macOS 无任务栏概念且会影响整个应用。
          await windowManager.setSkipTaskbar(true);
        }
        await _alignBottomRight();
        // 先置隐藏再按缓存请求显示,避免启动时闪一下。
        await windowManager.hide();
        _windowReady = true;
        final pending = _pendingVisible;
        if (pending == true) {
          await windowManager.show();
        }
        if (_passthrough) {
          await windowManager.setIgnoreMouseEvents(true, forward: true);
        }
        if (!_ready.isCompleted) _ready.complete();
      },
    );
    // 通知主进程可以接收指令(此前主进程会缓存状态并重发)。
    widget.link.send({'type': OverlayMessageType.ready});

    // 主进程若已退出,子进程不应残留。
    unawaited(widget.link.done.then((_) => _exit()));
  }

  /// 定位到主显示器工作区右下角(排除任务栏)。
  Future<void> _alignBottomRight() async {
    try {
      await windowManager
          .setAlignment(Alignment.bottomRight)
          .timeout(const Duration(seconds: 3));
      final position = await windowManager.getPosition().timeout(
        const Duration(seconds: 3),
      );
      await windowManager
          .setPosition(position - bottomRightMargin)
          .timeout(const Duration(seconds: 3));
    } on Object {
      // 定位失败(缺少屏幕信息等)不影响悬浮窗功能,窗口留在默认位置。
    }
  }

  Future<void> _onMessage(OverlayMessage message) async {
    switch (message['type']) {
      case OverlayMessageType.state:
        final bpm = message['bpm'];
        _viewModel.update(
          bpm: bpm is int ? bpm : null,
          connected: message['status'] == 'connected',
        );
        final styleJson = message['style'];
        if (styleJson is Map) {
          final style = OverlayStyle.fromJson(
            Map<Object?, Object?>.from(styleJson),
          );
          _viewModel.setStyle(style);
          await _applyWindowSize(style);
        }
      case OverlayMessageType.passthrough:
        final value = message['value'] == true;
        if (value != _passthrough) {
          _passthrough = value;
          if (_windowReady) {
            await windowManager.setIgnoreMouseEvents(value, forward: true);
          }
          if (mounted) setState(() {});
        }
      case OverlayMessageType.show:
        _pendingVisible = true;
        if (_windowReady) await windowManager.show();
      case OverlayMessageType.hide:
        _pendingVisible = false;
        if (_windowReady) await windowManager.hide();
      case OverlayMessageType.quit:
        await _exit();
    }
  }

  /// 背景板尺寸变化时同步调整窗口大小。
  Future<void> _applyWindowSize(OverlayStyle style) async {
    final target = Size(style.backgroundWidth, style.backgroundHeight);
    if (_lastWindowSize == target) return;
    _lastWindowSize = target;
    await windowManager.setSize(target);
  }

  Future<void> _exit() async {
    final onExit = widget.onExit;
    if (onExit != null) {
      await onExit();
      return;
    }
    await windowManager.destroy();
    exit(0);
  }

  /// 拖动(穿透关闭时生效)。
  void _startDrag() {
    if (!_passthrough) windowManager.startDragging();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: OverlayView(
            bpm: _viewModel.bpm,
            connected: _viewModel.connected,
            style: _viewModel.style,
            history: _viewModel.history,
            onPanStart: _startDrag,
          ),
        ),
      ),
    );
  }
}
