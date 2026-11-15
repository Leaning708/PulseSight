# 架构说明

本文描述 PulseSight 的分层架构、数据流、平台实现要点与已知平台陷阱。遵循 `.agents/skills/flutter-apply-architecture-best-practices` 技能规定的 MVVM 分层。

## 总体分层

```
┌──────────────────────────────────────────────────────────────────┐
│ UI 层(MVVM:View + ViewModel)                                    │
│  ui/features/home          主界面(连接管理 + 显示端开关 + 样式设置)│
│  ui/features/overlay       悬浮窗内容(三端复用,OverlayView)       │
│  ui/core                   HeartbeatHeart / BpmDisplay / 主题      │
├──────────────────────────────────────────────────────────────────┤
│ Data 层                                                          │
│  data/repositories   HeartRateRepository / SettingsRepository     │
│  data/services       HeartRateSource(抽象)+ 模拟源                │
│  data/services/platform  各显示端服务(悬浮窗/菜单栏/通知/字体)      │
├──────────────────────────────────────────────────────────────────┤
│ Domain 层                                                        │
│  domain/models     HeartRateReading / HeartRateHistory /          │
│                    OverlayStyle / HeartRateConnection             │
└──────────────────────────────────────────────────────────────────┘
```

状态管理:ChangeNotifier MVVM(`provider` 注入),View 用 `ListenableBuilder` 监听。

## 核心数据流

```
HeartRateSource(模拟)                    ← 未来:小米手环 BLE 广播实现
  └─ bpmStream / connectionStream
      HeartRateRepository               ← 唯一数据出口
        ├─ HomeViewModel                → HomeView(主界面)
        ├─ DesktopOverlayService        → WindowMethodChannel → 桌面悬浮窗引擎
        ├─ MacosMenubarService          → MethodChannel → NSStatusItem
        └─ AndroidDisplayService        ├─ shareData → Android 悬浮窗引擎
                                        └─ MethodChannel → 状态栏持续通知
```

每个显示端服务内部订阅 repository 的广播流并转发;样式(OverlayStyle)变更经同一条链路整包 JSON 推送。

## 悬浮窗样式系统(OverlayStyle)

不可变配置模型,覆盖:心形/数字大小与颜色、数字位置(上/下/左/右/隐藏)、bpm 标签开关、ECG 样式(关/直线/单峰/经典/数字)、ECG 颜色、心形与数字律动开关、辉光透明度/半径、背景板颜色/透明度/宽高。

- 持久化:`SettingsRepository`(SharedPreferences,`overlay.*` 键,类型注册表驱动读写)
- 推送:`_applyOverlayStyle` → 桌面 `WindowController.invokeMethod('update', {...style})` / Android `shareData({...style})` — 整包 JSON,悬浮窗引擎 `OverlayStyle.fromJson` 还原
- 三态联动:心形律动 / 文字律动 / 辉光强度 三者独立开关,可组合出 8 种动效状态

## 各平台显示端实现

### Windows / macOS 桌面悬浮窗

- `desktop_multi_window` 创建独立引擎的副窗口(args=`overlay`,启动即隐藏)
- 副窗口引擎内的 `windowManager`(window_manager 0.5.2,引擎级绑定)完成:
  无边框(`setAsFrameless`)、置顶、右下角初始定位(原生 `NSScreen.visibleFrame`)
- 纯透明窗口在 Flutter 3.50 桌面端(Skia)不可实现(三层透明修复后仍黑底,引擎层限制)——采用深色底板样式,底板颜色/透明度/宽高均可调
- 拖动:`onPanStart → windowManager.startDragging()`
- 样式推送:主窗口经 `WindowController.invokeMethod('update', {bpm, status, style})`;副窗口 `_handleMethodCall` 还原 OverlayStyle 并 `windowManager.setSize` 联动窗口尺寸
- 心率折线图:`HeartRateChart`(CustomPainter)置于悬浮窗底部

### macOS 菜单栏心率

- 原生 `NSStatusItem`(`MainFlutterWindow.swift`),无第三方依赖
- MethodChannel `pulsesight/menubar`:`setVisible(bool)` / `update({bpm, connected})`
- 标题 `♥ 72`(红色,等宽数字)或弱化 `♥ --`(未连接);菜单含「显示主窗口」「退出」
- 附带:SystemFontListSupport 通道(`pulsesight/fonts`)枚举 CoreText 字体族供字体下拉

### Android 悬浮窗

- `flutter_overlay_window`:SYSTEM_ALERT_WINDOW 权限流 + 独立 isolate 悬浮窗引擎(`overlayMain` 入口,**必须定义在 main.dart 根库**)
- `showOverlay(enableDrag, positionGravity: auto)`,拖动由插件原生处理
- 数据:主 isolate `shareData({bpm, status, style})` → 悬浮窗 isolate `overlayListener`
- 深色卡片样式,颜色跟随「心电图颜色」,尺寸跟随背景板宽高
- Manifest:SYSTEM_ALERT_WINDOW、POST_NOTIFICATIONS、FOREGROUND_SERVICE(_SPECIAL_USE)、OverlayService 注册

### Android 状态栏(持续通知)

- MethodChannel `pulsesight/status_bar`:`requestPermission` / `setEnabled` / `update({bpm, status})`
- NotificationCompat 持续通知(setOngoing + setOnlyAlertOnce),channel `heart_rate_status`,静态心形 drawable 小图标
- API 33+ 动态请求 POST_NOTIFICATIONS 权限

### macOS 菜单栏与字体枚举(原生)

- `SystemFontListSupport` 通道 `pulsesight/fonts`:`list` → `CTFontManagerCopyAvailableFontFamilyNames()` 过滤隐藏项排序返回

## 心率折线图(HeartRateChart)

- 纯 CustomPainter:水平网格线 + 面积填充 + 深色可读性描边 + ecgColor 折线 + 末端白描边当前点
- Y 轴动态范围(数据 min/max ±5bpm,跨度 ≥20bpm);X 轴铺满可用宽度,数据满后左移(滚动)
- 数据源:`HeartRateHistory`(定长 40 点缓冲)由 OverlayViewModel / HomeViewModel 分别维护(悬浮窗引擎与主界面各自独立)

## 心率动效(HeartbeatHeart)

- CustomPainter 绘制 Material 标准心形路径 + 自定义色渐变(亮部由主色向白插值)+ 高光 + 脉冲辉光
- **相位驱动**:painter 仅接收 `phase`(0~1),缩放系数 = `pulseSequence().evaluate(phase)` — 心形与文字共享同一相位即天然同步
- 三种驱动模式:内部控制器自驱动(独立使用)/ 外部 phase(OverlayView,与文字同步)/ 静止(未连接灰心)
- ECG 五样式:关 / 直线 / 单峰 / 经典 P-QRS-T / 数字(心内 TextPainter 绘制 bpm)
- 辉光:双层(内亮 + 外柔),强度倍率作用于模糊半径与透明度

## 数据源替换点(接入真实手环)

实现 `HeartRateSource` 接口(见 `lib/data/services/heart_rate_source.dart`):

```dart
abstract interface class HeartRateSource {
  Stream<int> get bpmStream;                 // 心率采样流
  Stream<HeartRateConnection> get connectionStream;
  HeartRateConnection get status;
  int? get currentBpm;
  Future<void> connect();
  Future<void> disconnect();
  void dispose();
}
```

新增 `MiBandBleHeartRateSource`(建议基于 `flutter_blue_plus`,监听标准 Heart Rate Service `0x180D` 的 measurement 特征)并在 `main.dart` 的 `_runMainApp` 中替换 `SimulatedHeartRateSource` 即可,上层 Repository / 显示端 / UI 均无需改动。

## 关键依赖版本(勿随意升级)

| 包 | 版本 | 说明 |
| --- | --- | --- |
| window_manager | **0.5.2 固定** | 0.6+ 重写为进程级绑定(nativeapi),与 desktop_multi_window 多引擎子窗口不兼容;0.5.x 为引擎级绑定。另:0.7 移除了 legacy API |
| desktop_multi_window | 0.3.1 | 副窗口创建 + 跨窗口通信(unidirectional channel) |
| flutter_overlay_window | 1.0.2 | Android 悬浮窗(注意 showOverlay 尺寸单位为物理像素) |
| flutter_colorpicker | 1.1.0 | 颜色选择器(需 Material 祖先,见排障手册) |
| provider | 6.x | DI(遵循架构技能规范) |
| shared_preferences | 2.x | 样式/开关持久化(SharedPreferencesAsync) |

## macOS 平台陷阱清单(高频踩坑)

1. **`setSkipTaskbar(true)` = 应用变 accessory**:NSApplication 进程级单例,副窗口调用会隐藏整个应用的 Dock 图标并让主窗口失去鼠标事件。macOS 永远不要调用。
2. **悬浮窗透明三件套**(详见上文):isOpaque × 2 + FlutterViewController.backgroundColor。
3. **CLT 与 Xcode 版本必须一致**,否则 xcodebuild 插件加载失败。
4. **CocoaPods 必须与 Homebrew Ruby 大版本匹配**,旧 gem shim 会抢占 PATH。
5. 鼠标穿透开启时,主窗口对一切鼠标事件透明(包括自动化工具的合成事件)— 自动化驱动前先关闭穿透。
