import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../domain/models/overlay_style.dart';
import 'overlay_view.dart';
import '../view_models/overlay_view_model.dart';

/// 桌面悬浮窗页面(Windows / macOS)。
///
/// 运行于 desktop_multi_window 创建的副窗口引擎内,负责:
/// - 自身窗口样式配置(无边框、透明、置顶、跳过任务栏、右下角初始位置)
/// - 注册跨窗口 MethodChannel handler,接收主窗口推送的 bpm / 状态 / 穿透开关
/// - 穿透关闭时通过 [windowManager.startDragging] 支持拖动
class DesktopOverlayPage extends StatefulWidget {
  /// 创建悬浮窗页面。
  const DesktopOverlayPage({super.key});

  @override
  State<DesktopOverlayPage> createState() => _DesktopOverlayPageState();
}

class _DesktopOverlayPageState extends State<DesktopOverlayPage> {
  final OverlayViewModel _viewModel = OverlayViewModel();

  /// 悬浮窗尺寸(逻辑像素)。
  static const Size windowSize = Size(140, 170);

  bool _passthrough = false;

  @override
  void initState() {
    super.initState();
    _registerMethodHandler();
    _configureWindow();
  }

  /// 副窗口引擎内必须先初始化 window_manager(绑定本引擎的 NSWindow),
  /// 否则后续任何窗口操作会在原生侧强解包 nil 导致崩溃。
  Future<void> _ensureWindowManager() async {
    await windowManager.ensureInitialized();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _registerMethodHandler() async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler(_handleMethodCall);
    } on Exception {
      // 非 desktop_multi_window 引擎(如热重载场景),忽略。
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'update':
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        _viewModel.update(
          bpm: args['bpm'] as int?,
          connected: args['status'] == 'connected',
        );
        final styleJson = args['style'];
        if (styleJson is Map) {
          final style =
              OverlayStyle.fromJson(Map<Object?, Object?>.from(styleJson));
          _viewModel.setStyle(style);
          _applyWindowSize(style);
        }
      case 'setPassthrough':
        final value = call.arguments as bool;
        if (value != _passthrough) {
          _passthrough = value;
          await windowManager.setIgnoreMouseEvents(_passthrough, forward: true);
          if (mounted) setState(() {});
        }
    }
    return null;
  }

  /// 背景板尺寸变化时同步调整悬浮窗窗口大小。
  void _applyWindowSize(OverlayStyle style) {
    final target = Size(style.backgroundWidth, style.backgroundHeight);
    if (_lastWindowSize != target) {
      _lastWindowSize = target;
      windowManager.setSize(target);
    }
  }

  Size? _lastWindowSize;

  Future<void> _configureWindow() async {
    await _ensureWindowManager();
    // 注意:macOS 下不能设置 skipTaskbar——window_manager 的实现是
    // NSApplication.shared.setActivationPolicy(.accessory),而
    // NSApplication 为进程级单例(多引擎共享),会把整个应用切成
    // 辅助模式,导致 Dock 图标消失、主窗口无法激活。
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: windowSize,
        backgroundColor: Colors.transparent,
        alwaysOnTop: true,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.setAsFrameless();
        await windowManager.setSize(windowSize);
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setAlwaysOnTop(true);
        if (!Platform.isMacOS) {
          // 仅 Windows 需要显式隐藏任务栏项;macOS 无任务栏概念。
          await windowManager.setSkipTaskbar(true);
        }
        // setAsFrameless 会强制 isOpaque = true,
        // 这里经原生辅助通道关闭不透明并定位;
        // 位置用 NSScreen.visibleFrame 定位,排除菜单栏与 Dock。
        try {
          const channel = MethodChannel('pulsesight/overlay_window');
          await channel.invokeMethod<void>('setTransparent');
          await channel.invokeMethod<void>('moveToBottomRight');
          debugPrint('[PulseSight] overlay transparency applied');
        } on Exception catch (e) {
          // 非 macOS 平台未注册该通道,交由平台自身的透明与定位实现。
          debugPrint('[PulseSight] overlay transparency failed: $e');
        }
        if (_passthrough) {
          await windowManager.setIgnoreMouseEvents(true, forward: true);
        }
        await windowManager.show();
      },
    );
  }

  void _startDrag() {
    if (!_passthrough) {
      windowManager.startDragging();
    }
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
