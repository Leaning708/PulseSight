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
