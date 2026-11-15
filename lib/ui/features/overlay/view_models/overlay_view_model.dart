import 'package:flutter/foundation.dart';

import '../../../../domain/models/heart_rate_history.dart';
import '../../../../domain/models/overlay_style.dart';

/// 悬浮窗 ViewModel。
///
/// 桌面副窗口与 Android 悬浮窗各自运行在独立 isolate,
/// 由宿主页面接收平台消息后调用 [update] / [setStyle],驱动悬浮窗刷新。
/// [history] 保留近期心率采样,供折线图展示近期波动。
class OverlayViewModel extends ChangeNotifier {
  /// 最近一次心率;为 null 表示未连接或暂无数据。
  int? get bpm => _bpm;

  /// 是否已连接。
  bool get connected => _connected;

  /// 近期心率采样历史(时间升序,供折线图使用)。
  HeartRateHistory get history => _history;

  /// 当前显示样式。
  OverlayStyle get style => _style;

  int? _bpm;

  bool _connected = false;

  OverlayStyle _style = OverlayStyle.defaults;

  final HeartRateHistory _history = HeartRateHistory();

  /// 用最新数据更新悬浮窗状态;仅在状态变化时通知监听者。
  void update({required int? bpm, required bool connected}) {
    final historyChanged = _appendHistory(bpm, connected);
    if (_bpm == bpm && _connected == connected && !historyChanged) return;
    _bpm = bpm;
    _connected = connected;
    notifyListeners();
  }

  /// 更新显示样式;仅在样式变化时通知监听者。
  /// 同步折线图历史缓冲长度(按采集时长折算)。
  void setStyle(OverlayStyle style) {
    if (_style == style) return;
    _style = style;
    _history.maxLength = style.chartSampleCount;
    notifyListeners();
  }

  /// 追加采样到历史;断连时清空陈旧数据。
  /// 返回历史是否发生变化。
  bool _appendHistory(int? bpm, bool connected) {
    if (!connected) {
      if (_history.values.isEmpty) return false;
      _history.clear();
      return true;
    }
    if (bpm == null) return false;
    _history.add(bpm);
    return true;
  }
}
