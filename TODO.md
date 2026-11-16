# TODO

按优先级记录已知的欠账与技术债。完成一项就把对应条目改写成已完成并注明版本。

## 待办

### 1. Windows 悬浮窗:切换回官方多窗口方案(临时方案的技术债)

- **现状**:Windows 桌面悬浮窗运行在**独立子进程**(`--overlay-process`),
  主进程通过回环 TCP 推状态。原因:Flutter 的 Windows 嵌入层不支持单进程
  多引擎(第二个视图会重置 EGL current context,导致 `flutter_windows.dll`
  随机 `0xc0000005`)。详见 [docs/troubleshooting.md](docs/troubleshooting.md) §10。
- **目标**:官方 **Desktop Windowing API** 转正后(单引擎多视图)改回进程内实现,
  删除子进程与 IPC 层,恢复"跨窗口状态零序列化"的能力。
- **切换信号**:`docs.flutter.dev` 的 release notes 出现 windowing 正式支持;
  `packages/flutter/lib/src/widgets/_window.dart` 从 `widgets.dart` 导出且
  去掉 `@internal`(跟踪 [#177586](https://github.com/flutter/flutter/issues/177586)、
  [#30701](https://github.com/flutter/flutter/issues/30701))。
- **切换时需要做的事**:
  1. 删除 `windows_overlay_process_service.dart`、`overlay_ipc.dart`、
     `overlay_process_page.dart`,以及 `main.dart` 中的子进程分支与
     `windows/runner` 里与之相关的参数透传;
  2. 用 `Window` / `WindowManager` + `runWidget` 替换现有副窗口实现,
     macOS 与 Windows 统一走该路径(届时可一并去掉
     `desktop_multi_window` 依赖);
  3. 迁移 `DesktopOverlay` 抽象的实现,保持 `HomeViewModel` 不变;
  4. 回归:`docs/troubleshooting.md` §10 的复现脚本连续跑 3 次不崩。
- **备注**:保留本项直到官方稳定版发布并完成第 4 步验证;在此之前不要把
  Windows 改回同进程多引擎。

### 2. Windows 悬浮窗视觉:透明背景受引擎限制

当前 Windows 上窗口背景由 DWM 合成决定,`Colors.transparent` 不保证像素级透明;
macOS 也因 Skia 限制采用深色底板方案。待引擎支持后统一为真透明(见
`docs/troubleshooting.md` §1 与 `OverlayStyle.backgroundOpacity`)。

### 3. OBS 浏览器源单测失败

`test/data/services/platform/obs_overlay_service_test.dart` 的
「停用后连接关闭且可重新启用」在本地持续失败(与本仓库其他改动无关),
需要单独排查是端口复用还是服务端 close 时序问题。
