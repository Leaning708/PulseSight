# 排障手册

开发过程中实际踩过的坑与已验证的解法。遇到"看起来应该工作但不工作"的情况,先查这里。

## macOS / 桌面端

### 1. 悬浮窗黑底(透明失败)

三层全透明缺一不可,任何一层不透明都会露出黑底:

1. `window.isOpaque = false`(`setAsFrameless` 会强制 `true`,必须在其后重设)
2. FlutterView 图层 `layer?.isOpaque = false`
3. **`FlutterViewController.backgroundColor = .clear`**(Flutter 3.7+ 默认黑色,最隐蔽的元凶)

已实现于 `MainFlutterWindow.swift` 的 `OverlayWindowSupport`(通道 `pulsesight/overlay_window`)。
即便如此,Flutter 3.50 的 Skia 后端在 macOS 27 上**仍无法渲染出真正的透明窗口**(桌面端观察为黑底)——这是引擎层限制。Android 端无此问题。

**当前方案**:桌面悬浮窗为深色底板样式,底板颜色/透明度可调;纯透明需求待引擎支持后再启用(代码已保留:OverlayStyle 中相关逻辑)。

### 2. 整个应用从 Dock 消失 / 鼠标事件全部穿透

**`window_manager.setSkipTaskbar(true)` 在 macOS 上会把整个应用切成 `.accessory`**(`NSApplication.shared.setActivationPolicy(.accessory)`),而 `NSApplication` 是进程级单例(所有引擎共享),副窗口调用会波及主窗口:
- Dock 图标消失
- 主窗口收不到鼠标事件(悬浮窗的穿透开关开着的表象)

解法:macOS 上**永远不要调用** `setSkipTaskbar`(代码已在 `DesktopOverlayPage` 中按平台条件屏蔽);Windows 上无此问题。
误开后修复:`defaults delete com.pulsesight.pulseSight desktop_overlay.mouse_passthrough` 后重启(或用主界面开关重设)。

### 3. 主窗口关闭后找不回来

`applicationShouldTerminateAfterLastWindowClosed` 返回 true 时关窗即杀进程。本项目已改为:

- 关闭按钮 = 隐藏(`performClose → orderOut`)
- 点击 Dock 图标恢复(`applicationShouldHandleReopen`,**不能依赖 `hasVisibleWindows` 标志**——悬浮窗始终可见会污染该标志,须直接检查主窗口 `isVisible`)

### 4. xcodebuild 报 "Failed to load code for plug-in com.apple.dt.IDESimulatorFoundation"(Symbol not found)

**Command Line Tools 与 Xcode 大版本不匹配**(如 CLT 26.5 + Xcode 26.6)。CLT 安装的私有框架 shadow 了 Xcode 的。

```bash
sudo xcodebuild -runFirstLaunch        # 官方修复
softwareupdate --list && sudo softwareupdate -i -a   # 更新 CLT 到与 Xcode 一致
```

验证:`pkgutil --pkg-info=com.apple.pkg.CLTools_Executables` 的版本应与 Xcode 一致。

### 5. pod 命令崩溃(NoMethodError / VersionConflict)

Homebrew Ruby 升级后,旧 gem 安装的 CocoaPods 失效。

```bash
rm -f /opt/homebrew/lib/ruby/gems/<旧版本>/bin/pod   # 清掉抢占 PATH 的旧 shim
brew install cocoapods                               # 用 brew 重装
hash -r && which pod && pod --version
```

### 6. ColorPicker 报 "No Material widget found"

flutter_colorpicker 的 ColorPicker 内部含 `DropdownButton`(rgb/hsv/hsl 格式切换),其 `debugCheckHasMaterial` 用 **LookupBoundary 有界查找**。已用 `Material` 包裹 ColorPicker 修复;若仍出现,可 `labelTypes: const []` 移除该下拉(格式标签为装饰性)。

### 7. 合成鼠标事件(CGEvent)收不到 Flutter 内容响应

macOS 真机上,CGEvent 合成的点击/滚轮能到达**原生层**(标题栏、关闭按钮),但 Flutter 内容区可能不响应(原因未查明,与鼠标穿透状态有关:穿透开启时全部穿透)。解法:

- 删除穿透偏好 + 重启:`defaults delete com.pulsesight.pulseSight desktop_overlay.mouse_passthrough`
- 或用主界面开关关闭穿透后再驱动

Android 端无此问题(`adb shell input` 完整可用)。

### 8. PageDown 键盘滚动无效

Flutter ListView 未持有键盘焦点。测试环境请用 `adb`(Android)或 CGEvent 滚轮(macOS,注意小增量多次,单次大增量会被截断)。

### 9. Windows 悬浮窗随机闪退(26–200 秒内进程消失)

**根因在 Flutter 嵌入层,应用层无法修复。** Windows 上 `desktop_multi_window` 为悬浮窗另起一个完整引擎;Flutter 的 Windows 嵌入层(`flutter_windows.dll`)在**单进程多引擎**下创建第二个视图时会重置平台线程的 EGL current context,污染第一个引擎 raster 线程状态,之后任意一帧都可能野指针 → 进程级 `0xc0000005`。

上游已声明该用法不受支持:[flutter#138248](https://github.com/flutter/flutter/issues/138248)、[flutter#152299](https://github.com/flutter/flutter/issues/152299)。

判定依据(本项目实测):

1. 事件日志中崩溃签名固定:`pulse_sight.exe` + `flutter_windows.dll` + `0xc0000005` + 同一构建内同一偏移。
2. 只与"是否存在第二个引擎"相关:关闭悬浮窗时长时间存活;开启后约 33/51/100/134 秒崩溃(6 次运行,每次最多 200 秒采样)。
3. **把悬浮窗内容换成空白 `ColoredBox` 仍会崩溃** → 与业务 widget / ViewModel / 跨窗口通道无关。
4. 与帧率正相关:连接设备后心跳动画约 60fps,渲染帧数激增,故表现为"一连接就秒退"。

排查时不要被"补了某个 Dart 空指针"误导:同期还修掉了 `DesktopOverlayPage._handleMethodCall` 漏写 `break` 导致 `TypeError` 的缺陷,那只会让**悬浮窗不刷新**(停在灰心 `--`),不会杀进程。

**当前处置(方案 B):Windows 悬浮窗改为独立子进程**

- 主进程调 `WindowsOverlayProcessService`:绑定 `127.0.0.1:0` → 用同一个 exe
  以 `--overlay-process --overlay-port=<port>` 拉起子进程 → 子进程连回端口;
- 子进程(`OverlayProcessPage`)是**单引擎进程**,窗口/透明/置顶/穿透全部正常
  (macOS 的 `DesktopOverlayPage` 那套逻辑在 Windows 上本来就是对的,只是
  不能放在同进程);
- 状态走换行 JSON:`state`(bpm/status/style)、`passthrough`、`show`/`hide`、
  `quit`,以及子进程的 `ready`(就绪后主进程补发快照,避免丢帧);
- 子进程崩溃/退出与主进程无关;主进程退出或链路断开时子进程自行退出,
  主进程侧另有兜底强杀,避免残留窗口;
- 连续启动失败 3 次后熔断,不再反复拉起。

实测(1920×1200、125% 缩放):开启后进程数 2,悬浮窗窗口 `136×170`
位于 `(1768,1018)` 且 `WS_EX_TOPMOST`;关闭开关时不拉起子进程;
结束主进程 3 秒内子进程消失、无残留。

> ⚠️ 这是**临时方案**,目的是绕开引擎缺陷。官方 Desktop Windowing API 转正后
> 应按 [TODO.md](../TODO.md) 第 1 条改回"单引擎多视图",并删除子进程与 IPC 层。
> 在此之前**不要**把 Windows 改回同进程多引擎。

复现脚本(验证没有回归):

```powershell
flutter build windows --debug
# 先让悬浮窗开关处于开启状态,再启动
$p = Start-Process "build\windows\x64\runner\Debug\pulse_sight.exe" -PassThru
Start-Sleep 10
# 期望:两个 pulse_sight 进程(主进程 + 悬浮窗子进程)
Get-Process pulse_sight | Select-Object Id, MainWindowTitle
# 结束主进程后,子进程应在数秒内自动退出
Stop-Process -Id $p.Id -Force; Start-Sleep 3
Get-Process pulse_sight -ErrorAction SilentlyContinue   # 期望为空
```

回归判据:**进程数=2**、悬浮窗窗口 `WS_EX_TOPMOST` 且位于工作区右下角、
主进程退出后无残留子进程;而不是像旧方案那样"看能不能撑过 200 秒"。

### 10. Windows 顶栏 ❤ 图标抽风(被挤成竖条并移位)

**症状**:

- 切到「显示端」页后,顶栏左上角的心形图标消失,同时在别处出现一条被横向挤压、
  纵向拉长的红色心形竖条(≈15×310px,品牌红约 50% 不透明度);切回其他页恢复。
- 鼠标移入/移出**带 `tooltip` 的按钮**(如右上角主题切换)时,同一竖条会闪现一瞬。

**根因**:上述两处都会产生 **saveLayer 合成图层** —— 前者是禁用行的
`Opacity(0.5)`,后者是 `Tooltip` 的 `FadeTransition`(150ms 淡入 / 75ms 淡出,
框架内硬编码)。**Windows 的 Impeller 后端在帧内存在 saveLayer 时,会把其它
文字/图标字形以错误变换光栅化**(实测顶栏 ❤ 被约 `scale(0.68, 14)` 画到别处,
并继承该图层的 alpha)。与 ❤ 本身无关,任何字形都可能被波及。

**判定依据**:

1. 只有含禁用行的「显示端」页静态复现;切到「模拟场景」正常;
2. 把禁用行改成"按颜色 alpha 变暗"(不建图层)后该页恢复;
3. **A/B 对照**:同一份 Dart 代码,人为加回 `Opacity(0.55)` 后——
   Impeller 下必现竖条并丢失 ❤,**Skia 下完全正常**(截图对比)。
   说明这是 Impeller(Windows)的后端缺陷,而非布局/绘制代码问题。

**最终解法(两层)**:

1. **渲染后端**:`windows/runner/main.cpp` 设置
   `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled)`,Windows 与
   macOS 统一走 Skia。这样所有 saveLayer 场景(tooltip 淡入淡出、dialog/menu
   路由过渡、`AnimatedOpacity`、SnackBar 等)一并免疫。
   ⚠️ 改的是 runner C++,**必须重新构建**(`flutter run -d windows`),
   热重载无效;也**不要**再用 `--enable-impeller` 启动,否则缺陷复现。
2. **代码层**:`SettingRow` 的禁用态改为颜色 alpha 衰减,不再建图层
   (`test/ui/core/widgets/setting_row_test.dart` 断言禁用行内内容没有
   `Opacity` 祖先),作为后端再变化时的防御。

> 经验:Windows 上出现"莫名字形错位/竖条/残影"时,先检查该帧有没有
> `Opacity` / `AnimatedOpacity` / `FadeTransition` / 带 `tooltip` 的控件。
> 另外注意 `windows/runner/*.cpp` **只能写 ASCII**:MSVC 在代码页 936 下把
> C4819(含非当前代码页字符)当作错误,中文注释会直接编译失败。


## Android 端

### 1. 悬浮窗空白(引擎启动失败)

logcat 关键字:`Could not resolve main entrypoint function`。
原因:flutter_overlay_window 的 `DartEntrypoint("overlayMain")` 只在**根库(main.dart)中解析入口函数** — overlayMain 定义在独立文件且未被 main.dart 引用时解析失败。
解法:overlayMain 必须定义在 main.dart(已修复,含注释说明)。

### 2. 悬浮窗尺寸错误(内容溢出)

`FlutterOverlayWindow.showOverlay(height/width)` 的单位是**物理像素**,不是逻辑像素。需按 `devicePixelRatio` 换算(见 `AndroidDisplayService.showOverlay`)。

### 3. 悬浮窗偶发空白(零尺寸竞态)

主应用切后台瞬间启动悬浮窗服务,FlutterView 可能停留在零尺寸。已用延迟 `resizeOverlay` 触发重布局缓解(`AndroidDisplayService.showOverlay`);若复现,再点一次开关或重开悬浮窗。

### 4. 状态栏通知图标未显示

通知已投递(dumpsys 可见)但状态栏小图标未出现 — 模拟器 API 37 的行为,真机待验证。按需求暂缓。

## 构建系统

### 1. Gradle wrapper "Premature EOF" / 反复重新下载

被中断的构建在 `~/.gradle/wrapper/dists/<版本>/<hash>/` 留下损坏的部分下载(无 .ok 标记)。

```bash
rm -rf ~/.gradle/wrapper/dists/gradle-<版本>-<type>
# 或用 curl 走代理手动下载完整 zip 放回该目录
```

### 2. Flutter 引擎产物下载 525 错误(storage.flutter-io.cn)

国内镜像源故障。`unset FLUTTER_STORAGE_BASE_URL` 改走官方 storage.googleapis.com(需代理),代理配置见 development.md。

### 3. Gradle 单测卡死

`flutter test` 正常,但含 `tester.runAsync` + 图片捕获的 widget 测试在特定场景会挂起 — 已移除该类测试(改用纯逻辑断言)。若新增卡住,检查是否在 widget 测试中用了 `toImage`。

## 其他

### Flutter 3.50 特有

- `package:flutter/material.dart` 导入已弃用 → 统一用 `package:material_ui/material_ui.dart`(material_ui 是 Material 库的包化版本,Flutter 官方出品)
- `Color.toARGB32()` 替代已弃用的 `Color.value`
- `Object.hash` 参数上限 20 个,字段多时用 `Object.hashAll([...])`
- 隐私:macOS Debug 构建 `FLTEnableImpeller=false` 已写入 Info.plist(Impeller 桌面端透明窗口支持不完整)

### 渲染后端

| 平台 | 后端 | 设置位置 |
|---|---|---|
| macOS | Skia | `macos/Runner/Info.plist`:`FLTEnableImpeller=false` |
| Windows | Skia | `windows/runner/main.cpp`:`project.set_impeller_switch(ImpellerSwitch::Disabled)` |
| Android / iOS | Impeller(默认) | 未改动 |

两端桌面都用 Skia 的原因见 §10(Impeller 在 Windows 上的 saveLayer 字形错位);
macOS 侧另有 Impeller 透明窗口支持不完整的限制。改后端后**必须重新构建**,
`flutter run --enable-impeller` 会覆盖 Skia 设置并复现缺陷。
