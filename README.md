# PulseSight

基于 Flutter 构建的跨平台实时心率监测应用:通过小米手环蓝牙广播获取心率,以透明悬浮窗、系统菜单栏、状态栏通知等形式实时展示,心形与心率文字随 bpm 同步律动,并支持近期心率波动折线图。

> 通过标准 BLE 心率服务(0x180D / 0x2A37)连接设备,兼容小米手环「心率广播」与心率带;
> 无设备时可用 `--dart-define=PULSESIGHT_SIMULATE_HEART_RATE=true` 启动模拟数据源。

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS | ✅ 已验收 | BLE 手环实测(小米手环 10)、悬浮窗(纯透明/穿透/拖动)、菜单栏心率、折线图、全套样式定制 |
| Android | ✅ 模拟器实测 | BLE 权限与扫描已接入,悬浮窗(可拖动)、状态栏持续通知、折线图 |
| Windows | ✅ 悬浮窗(独立进程) | BLE 走 flutter_blue_plus_winrt;悬浮窗以子进程运行以规避引擎多实例缺陷(见[排障手册 §9](docs/troubleshooting.md)),OBS 浏览器源可用 |

## 核心功能

- **真实设备连接**:扫描附近 BLE 设备并连接标准心率服务(0x180D),实时订阅测量值(0x2A37);支持小米手环「心率广播」、心率带等设备,断线自动重连(重连序列 1s / 2s / 4s)。连接前在设备上开启「心率广播」
- **模拟数据源**:无手环时以 `--dart-define=PULSESIGHT_SIMULATE_HEART_RATE=true` 启动随机游走 55–105bpm 的模拟心率,并支持低 / 中 / 高场景切换
- **实时心率展示**:心形按 bpm 频率单次脉冲律动,心内可选心电图动画(关/直线/单峰/经典/数字五种样式)
- **桌面悬浮窗**(macOS / Windows):纯透明背景,心形 + 数字 + 折线图,鼠标穿透开关,可拖动,背景板颜色/透明度/宽高可调。macOS 走进程内副窗口,Windows 走独立子进程(同一 exe 自举,规避引擎多实例缺陷),详见[架构说明](docs/architecture.md)
- **macOS 菜单栏心率**:NSStatusItem 实时显示 `♥ 72`,点击菜单可显示主窗口/退出
- **Android 悬浮窗**:可拖动卡片,跟随「心电图颜色」,自动缩放
- **Android 状态栏心率**:持续通知展示当前心率
- **心率折线图**:悬浮窗底部绘制近 30 秒心率波动曲线
- **样式定制**:心形/数字大小与颜色、文字字重/字体族(系统字体枚举)/透明度、辉光透明度与半径、心形与文字律动开关、辉光强度、背景板颜色/透明度/宽高 — 全部实时生效、自动保存

## 快速开始

```bash
flutter pub get
flutter run -d macos    # macOS
flutter run -d <设备>    # Android(需模拟器/真机)
```

连接心率设备:

1. 在手环上开启 **设置 → 心率广播**(小米手环 8/9/10 等,具体路径以固件为准);
2. 点击应用中的 **连接设备**,在弹窗中选择你的手环;
3. 手环不在列表中时,打开「显示全部蓝牙设备」或重新扫描;仍搜不到请检查电脑 / 手机的蓝牙与权限。

无手环时可启动模拟模式:

```bash
flutter run -d macos --dart-define=PULSESIGHT_SIMULATE_HEART_RATE=true
```

详见 [docs/development.md](docs/development.md)。

## 文档

- [架构说明](docs/architecture.md) — 分层、数据流、平台实现要点、已知陷阱
- [开发指南](docs/development.md) — 环境要求、常用命令、UI 自动化测试方法
- [排障手册](docs/troubleshooting.md) — 开发过程中踩过的坑与解法
- [待办事项](TODO.md) — 技术债与迁移计划(如 Windows 悬浮窗切回官方多窗口 API)
- [变更日志](CHANGELOG.md)

## 许可证

GPL-3.0,见 [LICENSE](LICENSE)。
