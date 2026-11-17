import 'heart_rate_device_scanner.dart';
import 'heart_rate_source.dart';

/// 真实 BLE 心率数据源:同时具备心率流与设备扫描能力。
abstract interface class RealHeartRateSource
    implements HeartRateSource, HeartRateDeviceScanner {}
