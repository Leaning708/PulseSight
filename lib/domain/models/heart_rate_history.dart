/// 近期心率采样历史缓冲(定长队列)。
///
/// 用于悬浮窗折线图展示近期心率波动:
/// - 连接中每次采样调用 [add],超出 [maxLength] 时移除最旧数据
/// - 断连时调用 [clear] 清空陈旧数据
/// - 调整 [maxLength] 后在下次采样时生效;需要立即截断可调用 [trim]
class HeartRateHistory {
  /// 创建历史缓冲;[maxLength] 为最大保留点数。
  HeartRateHistory({this.maxLength = 40});

  /// 最大保留点数(采集时长设置变化时可调整)。
  int maxLength;

  final List<int> _values = <int>[];

  /// 当前历史数据(只读视图,时间升序)。
  List<int> get values => List<int>.unmodifiable(_values);

  /// 点数是否足够绘制折线(≥2)。
  bool get hasEnoughData => _values.length >= 2;

  /// 追加一个采样点;超出上限时移除最旧数据。
  void add(int bpm) {
    _values.add(bpm);
    while (_values.length > maxLength) {
      _values.removeAt(0);
    }
  }

  /// 立即截断超出 [maxLength] 的旧数据。
  void trim() {
    while (_values.length > maxLength) {
      _values.removeAt(0);
    }
  }

  /// 清空历史。
  void clear() {
    _values.clear();
  }
}
