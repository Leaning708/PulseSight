# 开发指南

## 环境要求

| 组件 | 版本 | 备注 |
| --- | --- | --- |
| Flutter SDK | 3.50.0 stable(Dart 3.14) | 本项目在该版本开发验证 |
| Xcode | 26.6+ | **Command Line Tools 必须与 Xcode 大版本一致**(26.5 的 CLT 配 26.6 的 Xcode 会导致 xcodebuild 插件加载失败,见排障手册) |
| CocoaPods | 1.17+ | 用 `brew install cocoapods` 安装;不要用旧 Ruby 3.4 gem 装的旧版 |
| Android Studio | 含 Android SDK 36、模拟器 | cmdline-tools 建议安装;`flutter doctor --android-licenses` 接受许可 |
| VS2022(Windows 机器) | 含"使用 C++ 的桌面开发"负载 | 仅构建 Windows 端需要 |

## 常用命令

```bash
flutter pub get            # 拉取依赖
flutter analyze            # 静态分析(须零告警)
flutter test               # 全部测试
flutter run -d macos       # macOS 调试运行(连接真实 BLE 心率设备)
flutter run -d macos --dart-define=PULSESIGHT_SIMULATE_HEART_RATE=true  # 首次启动默认模拟模式
flutter build macos --debug
flutter build apk --debug  # Android(需 SDK)
```

### 蓝牙心率设备调试

- 默认数据源连接真实设备:在设备上开启「心率广播」→ 应用点「连接设备」→ 选择设备。扫描结果按「心率广播设备优先 + RSSI 降序」排序,弹窗可切换「显示全部蓝牙设备」
- 在「连接设备」弹窗底部选择「使用模拟数据」进入模拟模式,点击「停止模拟」回到真实设备;两种模式互斥。`PULSESIGHT_SIMULATE_HEART_RATE=true` 只作为**没有历史设置时**的初始默认模式
- macOS:App Sandbox 已勾选 Bluetooth,`Info.plist` 已声明用途说明;首次扫描会弹系统授权。若误点拒绝,到「系统设置 → 隐私与安全性 → 蓝牙」重新打开
- Android:Manifest 已声明 `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`(API 31+)与旧版蓝牙 / 定位权限;Android 11 及以下还需打开系统定位服务才能扫描 BLE
- 手环同时只能被一个中心设备连接:若已连手机 App,先在手机端断开,或在手环上重新开启心率广播
- 无硬件调试:实现 `BleHeartRateTransport` 的 Fake 即可驱动 `BleHeartRateSource` 的扫描 / 连接 / 重连状态机(见 `test/data/services/ble_heart_rate_source_test.dart`)

国内网络环境:Gradle/Maven 拉取失败时设置代理 —

```bash
export HTTP_PROXY=http://<proxy>:<port>
export HTTPS_PROXY=http://<proxy>:<port>
export GRADLE_OPTS="-Dhttp.proxyHost=<proxy> -Dhttp.proxyPort=<port> -Dhttps.proxyHost=<proxy> -Dhttps.proxyPort=<port>"
flutter build apk --debug
```

Flutter 引擎产物镜像(`storage.flutter-io.cn`)出现 525 时 `unset FLUTTER_STORAGE_BASE_URL` 改走官方源 + 代理。

## macOS 调试运行 vs 正式启动

- `flutter run -d macos`:调试控制台可见(Dart 异常会打印),但**应用不会出现在 Dock**——事件也会因鼠标穿透等设置而行为不同
- 验收/演示用正式启动:`flutter build macos --debug && open build/macos/Build/Products/Debug/pulse_sight.app`
- 正式启动经 LaunchServices 注册,Dock 图标、鼠标事件、Spotlight 均正常

## UI 自动化测试(CGEveent 驱动)

辅助功能权限授予终端宿主后,可用 Swift + CGEvent 脚本驱动 macOS UI(工程外脚本,放 /tmp 即可):

```bash
# 滚轮滚动(负值向下,小增量多次,单次大增量会被截断)
swift /tmp/wheel.swift <x> <y> <ticks>
# 单击
swift /tmp/click.swift <x> <y>
```

- 点击**原生标题栏**(如关闭按钮)有效;**Flutter 内容区的合成点击/滚轮可能收不到**——疑似 `setIgnoreMouseEvents(forward: true)` 状态或事件路由问题,尚未定论
- 因此 UI 驱动测试优先级:能不点就不点;必须点击时先关穿透(删除偏好键 `desktop_overlay.mouse_passthrough` 后重启)
- 截屏:`screencapture -x /tmp/x.png`(需屏幕录制权限)
- 窗口枚举:Swift `CGWindowListCopyWindowInfo` 脚本(工程 /tmp 脚本样式见 git 历史)

> 注意:Flutter ListView 收不到合成滚轮事件的原因未查明;在模拟器/Android 端可用 `adb shell input` 完整驱动。

## Android 模拟器工作流

```bash
~/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_37.0 -no-snapshot-save -no-boot-anim &
flutter build apk --debug
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
# 授权(免 UI):
adb shell appops set com.pulsesight.pulse_sight SYSTEM_ALERT_WINDOW allow
adb shell pm grant com.pulsesight.pulse_sight android.permission.POST_NOTIFICATIONS
adb shell am start -n com.pulsesight.pulse_sight/.MainActivity
adb exec-out screencap -p > /tmp/and.png      # 截屏
adb shell input tap <x> <y>                    # 点击
adb shell input swipe <x1> <y1> <x2> <y2> <ms> # 滑动/拖动
adb logcat -d | grep -E "flutter|pulse"        # 日志
```

> install -r 后**首个 tap 可能被吞**(resume 时序),连续驱动时每个动作后截图确认状态。

## 样式系统

悬浮窗全部样式收敛在 `OverlayStyle`(不可变模型,`copyWith`/`toJson`/`fromJson`),持久化到 SharedPreferences(`overlay.*` 键,类型注册表见 `SettingsRepository._knownKeys`),并经平台通道整包 JSON 推送到悬浮窗引擎:

- 桌面副窗口:DesktopOverlayService.`_push()` → `WindowController.invokeMethod('update', {...})`
- Android 悬浮窗:`FlutterOverlayWindow.shareData({...})`
- 心形与文字律动:`HeartbeatPulse` 组件提供 pulse/phase,`OverlayView` 条件应用

新增样式字段的步骤:

1. `OverlayStyle` 加字段 + 构造参数 + copyWith + toJson/fromJson + ==/hashCode(hashCode 用 `Object.hashAll`,字段超过 20 个不能用 `Object.hash`)
2. `SettingsKeys` 加键 + `SettingsRepository._knownKeys` 注册类型(bool/double/string)
3. `HomeViewModel`:init 加载 + setter(`_applyOverlayStyle` 推送)+ `persistOverlayStyle` 落盘
4. `OverlayView`/`HeartbeatHeart`/`BpmDisplay` 消费
5. 悬浮窗引擎页面(`DesktopOverlayPage`/`AndroidOverlayPage`)从消息还原样式

## 测试

- 单元/widget 测试镜像 lib 目录结构,`flutter test` 一键运行;BLE 解析与连接状态机均有无硬件单测(见 `test/data/services/`)
- 组件探针:widget 测试先行验证渲染异常(如 ColorPicker 的 LookupBoundary 问题在测试环境不重现,需要真机日志)
- macOS 真机日志:直接运行二进制 `.../MacOS/pulse_sight > /tmp/app.log 2>&1 &`(flutter run 的 stdout 在管道中有缓冲延迟)
