# 桌面主界面(UI)设计说明

本文描述主界面的桌面设置式布局、主题体系与相关约定。架构分层见
[architecture.md](architecture.md)。

## 布局:按窗口宽度自适应

主界面只有一个 `HomeView`,通过 `LayoutBuilder` 按窗口宽度切换布局,
不判断设备类型(遵循 flutter-build-responsive-layout 技能):

| 窗口宽度 | 布局 | 结构 |
| --- | --- | --- |
| `≥ desktopBreakpoint`(720) | 桌面设置式布局 | 顶部栏(品牌 + 状态胶囊 + 主题切换)+ 左侧导航栏 200px + 右侧详情面板(IndexedStack 按导航切换) |
| `< 720` | 窄布局(手机形态) | `AppBar` + 单列 `ListView`,结构与旧版保持一致 |

- 断点、导航栏宽度与详情面板内容宽度上限定义在
  `lib/ui/core/theme/app_dimens.dart`(`desktopBreakpoint` /
  `desktopNavRailWidth` / `desktopPaneMaxWidth`)。
- 布局根节点挂有 `Key('home_desktop_layout')` / `Key('home_narrow_layout')`,
  widget 测试据此断言;导航栏为 `Key('desktop_nav_rail')`,条目为
  `Key('desktop_nav_<monitor|scenario|display|style>')`,详情面板为
  `Key('desktop_pane_<...>')`。
- 详情面板用 `IndexedStack` 承载:切页保留各页滚动位置与控件状态。

### 导航条目与详情面板

条目按平台能力位显隐,与面板一一对应,默认停留在「监视器」:

| 条目 | 面板内容 |
| --- | --- |
| 监视器 | 居中 `ConnectionSection`(红心 + bpm 大字 + 状态胶囊 + 连接按钮) |
| 模拟场景 | `ScenarioSection`(低 / 中 / 高切换) |
| 显示端 | `DisplayTogglesSection`(各显示端开关 + OBS 地址) |
| 悬浮窗样式 | `OverlayStylePane`(左预览固定 + 右分组控件滚动) |

### sections 文件组织

各区块为「内容组件」(不含标题),由窄布局与桌面详情面板共用,位于
`lib/ui/features/home/views/sections/`:

```
sections/
├── connection_section.dart     # ConnectionSection(连接区,监视器页复用)
├── scenario_section.dart       # ScenarioSection(低/中/高切换)
├── display_toggles_section.dart# DisplayTogglesSection(各显示端开关,SettingRow)
├── overlay_style_section.dart  # OverlayStyleSection(窄布局:预览 + 控件)
│                               #   OverlayStylePreview(深色舞台预览,可复用)
│                               #   OverlayStyleControls(全部样式控件,分组呈现)
└── overlay_style_pane.dart     # OverlayStylePane(桌面样式页:预览固定 + 控件滚动)
```

新增设置区块时:先写内容组件,再分别接入窄布局与桌面详情面板。

### 悬浮窗样式控件的分组约定

样式控件(约 30 项)按语义分为四组,由 `OverlayStyleControls` 统一呈现,
窄布局与桌面样式页自动继承,组间 24px、组内 12px:

| 组 | 内容 |
| --- | --- |
| 尺寸与布局 | 心形 / 数字大小、间距、心率与背景板透明度、背景板宽高、数字位置、bpm 标签开关 |
| 颜色 | 背景板 / 心脏 / 心电图 / 文字四组预设色板(含自定义色) |
| 图表 | 折线图开关、采集时长、折线图高度、图表间距、折线图颜色 |
| 动效与文字 | 心形 / 文字律动、辉光透明度与半径、心电图样式、字重、字体 |

- 滑块行(`_StyleSlider`)尾部常驻实时数值,拖动提示与静态显示一致;
- 预览与控件并排的最小宽度为 `overlayStyleSideBySideMinWidth`(560),
  桌面样式页左列预览(260×330)固定不随右侧控件滚动。

## 主题体系

`lib/ui/core/theme/app_theme.dart` 用一个 `_build(Brightness)` 生成
浅 / 深两套 `ThemeData`,入口 `AppTheme.light` / `AppTheme.dark`:

- 色彩:`ColorScheme.fromSeed(seedColor: 0xFFE53935)`;深色方案的
  surface 系列手动中性化(避免种子色染出的红棕底,衬托红色辉光)。
- 「监视器」舞台色 `AppTheme.stageColor`(0xFF17181C):预览舞台在
  深浅主题下均用深色底,与实际悬浮窗观感一致。
- 组件主题:Card(圆角 16、描边 outlineVariant)、Chip、Dialog、Slider、
  ListTile、Divider、SnackBar(floating)统一在主题层配置,组件内
  不要散落写死样式。
- 设计令牌:间距用 `AppSpacing`、圆角用 `AppRadius`
  (`lib/ui/core/theme/app_dimens.dart`),不使用裸数字。

## 暗色模式

- `PulseSightApp` 配置 `theme` / `darkTheme` / `themeMode`,
  `themeMode` 来自 `HomeViewModel.themeMode`(默认跟随系统)。
- 界面右上角的循环切换按钮:跟随系统 → 浅色 → 深色,持久化到
  `SettingsKeys.themeMode`(`app.theme_mode`,存枚举名字符串)。
- 悬浮窗三端页面(桌面副窗口 / Android 悬浮窗 / OBS 页)不接入主题
  切换:其视觉完全由 `OverlayStyle` 驱动,与 App 主题解耦。

## 主窗口桌面配置

`lib/main.dart` `_runMainApp()` 中,macOS / Windows 主窗口通过
`window_manager`(0.5.2,版本约束见 architecture.md)设置:

- 默认尺寸 1120×760,最小 880×620,启动居中,标题 PulseSight;
- **隐藏原生标题栏**(`titleBarStyle: TitleBarStyle.hidden`),
  由 `HomeView` 的桌面顶部栏(`_DesktopHeader`)承担窗口控制:
  - 底层 `DragToMoveArea` 垫底:整条顶部栏可拖拽移动,双击最大化 / 还原;
    拖拽区必须**垫在按钮下层**(Stack 分层)而非包裹按钮,否则双击识别器
    会让按钮单击延迟约 300ms 才响应;
  - macOS:系统在顶部约 28px 透明标题栏区保留红绿灯,该区域由系统处理
    拖拽且 Flutter 控件收不到点击,内容行整体下移至其下方(横向无需
    避让,应用名称可靠左显示);
  - Windows:右上角自绘最小化 / 最大化(还原)/ 关闭按钮
    (`_WindowsCaptionButtons`,`WindowListener` 同步最大化状态),
    顶栏内容行为其预留右侧宽度。

macOS 上原生窗口外观需与主题联动:Flutter 侧的主题模式持久化在标准
UserDefaults 域(`app.theme_mode`),`MainFlutterWindow.swift` 监听
`UserDefaults.didChangeNotification` 同步窗口 appearance
(dark → darkAqua,light → aqua,无值 → 跟随系统),无需额外通道。

macOS 顶部菜单栏状态项(♥)的下拉菜单提供显示端开关条目:桌面悬浮窗 /
鼠标穿透 / 菜单栏心率 / OBS 浏览器源,经 `pulsesight/app_menu` 通道与
`HomeViewModel` 双向同步——勾选与可用状态由 VM 推送,条目点击转发回 VM
执行与开关行等价的切换;鼠标穿透条目在桌面悬浮窗关闭时置灰;状态项菜单
重建时(如菜单栏心率被重新开启)原生经 refresh 请求当前状态对齐勾选。

## 相关约定

- 注意事项悬浮窗样式设置项的扩展步骤见 development.md;
- 主题只影响主窗口;给悬浮窗增加新样式字段的步骤见
  [obs-overlay-parity.md](obs-overlay-parity.md)。
