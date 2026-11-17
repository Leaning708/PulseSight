/// 附近可连接的心率设备(BLE 扫描结果)。
///
/// 只承载界面选择设备所需的最小信息;平台相关的连接对象留在 Data 层,
/// 避免 UI 依赖具体蓝牙插件。
class HeartRateDevice {
  /// 创建设备描述。
  const HeartRateDevice({
    required this.id,
    this.name = '',
    this.rssi,
    this.advertisesHeartRate = false,
    this.isRemembered = false,
  });

  /// 平台侧设备标识(Android 为 MAC 地址,iOS / macOS 为随机 UUID)。
  final String id;

  /// 广播名称,可能为空字符串。
  final String name;

  /// 信号强度(dBm),未知时为 null。
  final int? rssi;

  /// 广播包中是否声明了标准心率服务(0x180D)。
  final bool advertisesHeartRate;

  /// 是否为上次连接过的设备。
  ///
  /// 小米手环断开连接后可能停止广播设备名与 0x180D 服务标记,
  /// 但仍可按系统设备 ID 直接重连;该标记用于让这类设备继续显示在列表中。
  final bool isRemembered;

  /// 供界面展示的名称,广播名称为空时回退为「未命名设备」。
  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '未命名设备' : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HeartRateDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'HeartRateDevice($id, name: $name, rssi: $rssi, '
      'advertisesHeartRate: $advertisesHeartRate, '
      'isRemembered: $isRemembered)';
}
