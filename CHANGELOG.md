# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式,
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- **Android 悬浮窗「触摸穿透」**:开启后触摸作用于下层应用,悬浮窗仅作展示;
  与桌面端「鼠标穿透」分开命名,手机端不再借用鼠标语义
- **Android 悬浮窗「边缘吸附」开关**:拖动松手后是否自动吸附到最近的左右边缘,
  默认开启
- **Android 悬浮窗位置记忆**:拖动结束后按逻辑像素持久化,下次显示/重启后从
  原位恢复;跨方向恢复时由原生按新屏幕边界夹取
- **心跳辉光开关**:悬浮窗样式新增「辉光 → 心跳辉光」开关,关闭后不再绘制
  外扩光晕,半径/透明度设置保留;关闭时两个滑块自动置灰不可调
- **字体选择改为可搜索弹层**:每行按该字体渲染名称与 `Aa 123` 样张,底栏实时
  显示匹配数量
- **真实 / 模拟模式切换 UI**:「连接设备」弹窗底部新增「使用模拟数据」,进入模拟模式时自动断开真实设备并持久化(`heart_rate.mode`);模拟模式自动开始模拟,三档场景选择内联在连接按钮下方(移除独立「模拟场景」导航页与模式选择卡片),「停止模拟」回到真实设备模式,两种数据源严格互斥
- **真实设备连接(BLE 心率广播)**:`BleHeartRateSource` + `BleHeartRateTransport` 抽象 + `FlutterBlueHeartRateTransport`(flutter_blue_plus 2.3.15),扫描并连接标准心率服务 0x180D,订阅 0x2A37 测量值,支持 8/16 位解析、未佩戴 0 值过滤、断线自动重连(1s/2s/4s)
- **设备选择弹窗**:默认只列出广播 0x180D 的设备(按 RSSI 排序),可切换「显示全部蓝牙设备」;连接后主界面展示设备名,失败原因直接显示
- **设备扫描能力接口** `HeartRateDeviceScanner`:与模拟场景能力同一套探测方式,UI 不依赖具体数据源
- **测试**:心率测量解析、BLE 连接状态机(扫描 / 连接 / 断开 / 重连耗尽 / 自动选择)、设备选择弹窗与扫描 ViewModel 状态
- **Windows 悬浮窗(独立进程方案)**:`WindowsOverlayProcessService` + `overlay_ipc.dart`(回环 TCP / 换行 JSON)+ `OverlayProcessPage`。同一个 exe 以 `--overlay-process` 自举子进程,主进程只负责拉起、推送心率/样式快照与显隐/穿透指令;子进程崩溃不影响主界面,主进程退出时子进程自动回收。用于规避 Flutter Windows 嵌入层不支持单进程多引擎的限制,详见 `docs/troubleshooting.md` §9 与架构说明
- **核心**:模拟心率数据源(`SimulatedHeartRateSource`,随机游走 55–105bpm,连接状态机),`HeartRateSource` 抽象接口为 BLE 数据源预留替换点(已落地,见上)
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

- **macOS 缩放窗口时交通灯抖动**:原先在 `didResize` 通知里异步校正,晚一帧
  导致按钮先回到默认位置再被拉回;改为重写 `setFrame` 在同一次布局内同步
  定位,实测连续 5 次改尺寸后位置无中间态
- **macOS 交通灯相对顶栏红心偏右**:几何对齐时两者中心重合,但红心是 22pt
  实心图形、交通灯是 12pt 小圆点,视觉重心不同;灯组起点由 20pt 调到 17pt
- **Android 启动图标黑边过大、心形不居中**:自适应前景图心形仅占画布约 35%
  (前景 51% 再叠加 16% inset),且缺少桌面图已有的光学居中偏移;改为
  `adaptive_icon_foreground_inset: 0` 并补上 3.5% 边长的下移,占比提升到 51.5%
- **连接设备弹窗文字/开关颜色异常**:监视舞台整体覆盖深色 `Theme` 会被
  `showDialog` 继承,导致浅色弹窗底色配深色方案的浅色文字;改为只给状态胶囊
  与场景分段控件单独套深色方案
- **重启后「悬浮窗」开关显示为开、实际没有悬浮窗**:启动时恢复上次开启的
  悬浮窗,权限被收回时回落为关闭
- **「触摸穿透」开关不生效**:`updateFlag` 走的是只有悬浮窗引擎才注册的通道,
  主界面调用被静默丢弃;改走主引擎通道并转发给悬浮窗服务
- **横屏下悬浮窗无法贴到屏幕左右边缘**:插件只在服务创建时读取一次屏幕尺寸,
  旋转后仍按旧方向夹取
- **macOS 左上角交通灯偏左**:隐藏标题栏后系统按钮仍停在约 7pt,与内容区间距不一致;`MainFlutterWindow` 统一右移到 20pt,使关闭按钮中心与标题行心形图标对齐,并在窗口缩放 / 退出全屏后重新校正
- **断开后另一台设备无法连接**:断连改为 `queue: false` 绕过 FBP GATT 操作队列,避免排队的 disconnect 被卡住、直到 App 退出才释放物理链路
- **Windows 控制台 AXTree 报错**:Flutter Windows 可访问性桥在「滚动列表 + Tooltip」组合下会刷 `Failed to update ui::AXTree`(flutter/flutter#182444)。窄布局改用 `SingleChildScrollView + Column`,Tooltip 外层增加语义边界以规避
- **断开后无法重新扫描到手环**:小米手环在 GATT 断开后会停止广播设备名与 `0x180D` 服务标记(扫描结果仍在,但名称为空且不再声明心率服务),默认过滤会把它隐藏。现在持久化上次连接的设备 ID / 名称,按 ID 合并扫描结果并以「上次连接」标记展示,可直接重连,无需重新开关手环广播
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

- **界面重构为中性色板 + 分组卡片**:主界面心率收进深色「监视舞台」,
  分区改为「标题 → 卡片」两级层次;AppBar 与画布同色、无阴影
- **悬浮窗样式重排为六组**:图形 → 文字 → 心电图 → 背景 → 辉光 → 图表;
  移除移动端预览(窄屏本身即可看到实际悬浮窗)
- **配置项文案精简**:分组标题已提供上下文,条目只保留必要信息
- **样式字段命名梳理**:`opacity` → `contentOpacity`、`gap` → `heartTextGap`、
  `text*` 系列统一为 `bpm*`;设置键同步改名并提供一次性旧键迁移
- **悬浮窗插件内置副本**:`third_party/flutter_overlay_window`(含 5 个本地
  补丁,见其 `PATCHES.md`),通过 `dependency_overrides` 生效
- **默认数据源改为真实 BLE**:默认连接心率广播设备;主界面可随时切换到
  模拟模式(`PULSESIGHT_SIMULATE_HEART_RATE=true` 仅是无历史设置时的初始默认值),
  真实 / 模拟模式互斥,场景切换 UI 仅在模拟模式显示
- **「连接手环」改为「连接设备」**:状态文案去掉「模拟」,连接中可取消,已连接显示设备名;页脚更新为 BLE 连接说明
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
