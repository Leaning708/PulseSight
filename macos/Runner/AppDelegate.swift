import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// 主窗口关闭后 App 继续运行(悬浮窗、菜单栏继续工作);
  /// 退出统一走菜单栏「退出 PulseSight」或 Cmd+Q。
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return false
  }

  /// 点击 Dock 图标时恢复主窗口。
  ///
  /// 不能依赖 `hasVisibleWindows`:心率悬浮窗始终可见,会把该标志
  /// 置为 true,导致误判"仍有可见窗口"而拒绝恢复主窗口。
  /// 因此只要主窗口本身不可见,就把它找回来。
  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if let mainWindow = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
       !mainWindow.isVisible {
      mainWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
