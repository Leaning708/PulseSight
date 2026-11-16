# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式,
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- **Windows 悬浮窗(独立进程方案)**:`WindowsOverlayProcessService` + `overlay_ipc.dart`(回环 TCP / 换行 JSON)+ `OverlayProcessPage`。同一个 exe 以 `--overlay-process` 自举子进程,主进程只负责拉起、推送心率/样式快照与显隐/穿透指令;子进程崩溃不影响主界面,主进程退出时子进程自动回收。用于规避 Flutter Windows 嵌入层不支持单进程多引擎的限制,详见 `docs/troubleshooting.md` §9 与架构说明
- **核心**:模拟心率数据源(`SimulatedHeartRateSource`,随机游走 55–105bpm,连接状态机),`HeartRateSource` 抽象接口为后续小米手环 BLE 广播预留替换点
- **悬浮窗**(Windows/macOS):desktop_multi_window 副窗口 + window_manager 0.5.2(引擎级绑定),无边框/置顶/右下角定位/鼠标穿透开关/拖动;macOS 悬浮窗透明三件套修复
- **悬浮窗**(Android):flutter_overlay_window 集成,SYSTEM_ALERT_WINDOW 权限流,可拖动,深色卡片,尺寸按 DPR 换算,零尺寸竞态缓解
- **macOS 菜单栏**:NSStatusItem 实时心率(`♥ 72`/灰 `♥ --`),显示主窗口/退出菜单;文字律动与心形同步
- **Android 状态栏**:持续通知展示当前心率(POST_NOTIFICATIONS 动态授权)
- **心率动效**:Material 标准心形 + 相位驱动脉冲 + 心内 ECG 五样式(关/直线/单峰/经典/数字)
- **心率折线图**:悬浮窗底部近 30 秒心率波动曲线(CustomPainter,动态 Y 轴,面积填充,当前点)
- **样式系统**:OverlayStyle 全字段定制(心形/数字大小、五位置、五 ECG 样式、双透明度、背景板颜色/透明度/宽高、文字颜色、字重、字体族、律动开关 ×2、辉光半径/透明度),实时推送悬浮窗引擎,SharedPreferences 持久化
- **字体枚举**:macOS CoreText 系统字体族列表(字体下拉)
- **文档**:架构说明 / 开发指南 / 排障手册

### Fixed

- Windows 顶栏 ❤ 图标抽风(切到「显示端」必现、移入/移出带 tooltip 的按钮时闪现):根因是 Impeller(Windows)在帧内含 saveLayer(`Opacity` / `FadeTransition`)时把其它字形以错误变换光栅化。Windows runner 改用 Skia 后端(`ImpellerSwitch::Disabled`,与 macOS 一致),并从代码层去掉禁用行的 `Opacity` 图层。详见 `docs/troubleshooting.md` §10
- 悬浮窗数据推送链路中断:`DesktopOverlayPage._handleMethodCall` 的 `update` 分支漏写 `break`,继续落入 `setPassthrough` 对 Map 做 `as bool` 强转抛 `TypeError`,副窗口不再刷新(永远显示灰心 `--`)。已补 `break` 并新增推送链路测试
- `setWindowMethodHandler` 未 `await`,导致首帧推送可能早于处理器注册
- 悬浮窗黑底:窗口/图层/FlutterViewController 三层透明 + Skia 后端(FLTEnableImpeller=false)组合修复(macOS 27 引擎限制,桌面端采用深色底板方案)
- macOS Dock 图标消失/鼠标穿透全窗口:`setSkipTaskbar` 在 macOS 上会将应用切为 accessory(NSApplication 进程级单例),已按平台屏蔽
- 主窗口关闭后无法恢复:关闭改为隐藏,Dock 点击/菜单恢复(reopen 处理不再依赖被悬浮窗污染的 hasVisibleWindows)
- 数字位置左右颠倒;文字与心形律动同步(共享 HeartbeatPulse 相位)
- ColorPicker "No Material widget found":Material 包裹 + labelTypes 清空(LookupBoundary 有界查找)
- Gradle 首次构建 525/网络失败:镜像切换官方源 + 代理;gradle-9.5.0-all dist 完整缓存

### Changed

- **Windows 悬浮窗恢复可用**:由"暂停提供 + 界面提示"改为**独立子进程**渲染,与 macOS 的进程内方案并存(两端共用 `DesktopOverlay` 抽象,UI 与 ViewModel 无感)
- README 重写为当前功能集;新增架构/开发/排障文档
- macOS 构建启用 Skia 后端(FLTEnableImpeller=false)
- 主窗口关闭改为隐藏(Dock/菜单恢复),退出统一走菜单栏/Cmd+Q

### Known Issues

- **Windows 悬浮窗为临时方案**:待官方 Desktop Windowing API 转正后需改回单引擎多视图,迁移清单见 `TODO.md` 第 1 条

## [0.1.0] — 初始化

### Added

- Flutter 3.50 项目脚手架(android/windows/macos)
- GPLv3 LICENSE、AGENTS.md、README、.gitignore、.gitattributes、docs 骨架
- `.dsh/skills → .agents/skills`、`.claude/skills → .agents/skills`、`CLAUDE.md → AGENTS.md` 软链
