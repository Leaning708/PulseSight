import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../../domain/models/overlay_style.dart';
import 'overlay_view.dart';
import '../view_models/overlay_view_model.dart';

/// Android 悬浮窗页面。
///
/// 运行于 flutter_overlay_window 启动的独立 isolate 中,
/// 通过 [FlutterOverlayWindow.overlayListener] 接收主应用推送的心率状态。
class AndroidOverlayPage extends StatefulWidget {
  /// 创建悬浮窗页面。
  const AndroidOverlayPage({super.key});

  @override
  State<AndroidOverlayPage> createState() => _AndroidOverlayPageState();
}

class _AndroidOverlayPageState extends State<AndroidOverlayPage> {
  final OverlayViewModel _viewModel = OverlayViewModel();

  StreamSubscription<dynamic>? _listenerSub;

  @override
  void initState() {
    super.initState();
    _listenerSub = FlutterOverlayWindow.overlayListener.listen(_onMessage);
  }

  @override
  void dispose() {
    _listenerSub?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  void _onMessage(dynamic message) {
    if (message is! Map) return;
    final styleJson = message['style'];
    if (styleJson is Map) {
      _viewModel.setStyle(
        OverlayStyle.fromJson(Map<Object?, Object?>.from(styleJson)),
      );
    }
    _viewModel.update(
      bpm: message['bpm'] as int?,
      connected: message['status'] == 'connected',
    );
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
          ),
        ),
      ),
    );
  }
}
