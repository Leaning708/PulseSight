import Cocoa
import FlutterMacOS
import CoreText
import desktop_multi_window

/// 系统字体枚举通道:返回 CoreText 已注册的字体族列表(排除隐藏项)。
final class SystemFontListSupport {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pulsesight/fonts",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "list":
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        let visible = names
          .filter { !$0.hasPrefix(".") }
          .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        result(visible)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// 悬浮窗辅助通道:补足 window_manager 未暴露的窗口透明开关。
///
/// 黑底修复三件套(缺一不可):
/// 1. window.isOpaque = false( setAsFrameless 会强制 true)
/// 2. FlutterView 图层 isOpaque = false
/// 3. FlutterViewController.backgroundColor = .clear
///    (Flutter 3.7+ 该属性默认黑色,是黑底的真正元凶)
final class OverlayWindowSupport {
  static func register(with controller: FlutterViewController) {
    controller.backgroundColor = NSColor.clear
    let channel = FlutterMethodChannel(
      name: "pulsesight/overlay_window",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard let window = controller.view.window else {
        result(nil)
        return
      }
      switch call.method {
      case "setTransparent":
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        // FlutterView 的 CAMetalLayer 默认不透明,必须一并关闭,
        // 否则窗口透明后渲染层仍是黑底。
        controller.view.wantsLayer = true
        controller.view.layer?.isOpaque = false
        controller.backgroundColor = NSColor.clear
        NSLog("[PulseSight] overlay window setTransparent applied")
        result(true)
      case "moveToBottomRight":
        // NSScreen.visibleFrame 已排除菜单栏与 Dock,定位最准确。
        let visibleFrame = NSScreen.main?.visibleFrame
          ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window.setFrameOrigin(
          NSPoint(
            x: visibleFrame.maxX - window.frame.width - 16,
            y: visibleFrame.minY + 12))
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

class MainFlutterWindow: NSWindow {
  /// 菜单栏心率显示的 NSStatusItem。
  private var statusItem: NSStatusItem?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // desktop_multi_window:在悬浮窗等副窗口引擎中注册插件,
    // 使副窗口可访问 window_manager 等平台通道。
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      OverlayWindowSupport.register(with: controller)
    }

    setupMenuBarChannel(with: flutterViewController.engine.binaryMessenger)
    SystemFontListSupport.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// 注册菜单栏心率显示的 MethodChannel,方法名与
  /// lib/data/services/platform/macos_menubar_service.dart 保持一致。
  private func setupMenuBarChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pulsesight/menubar",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setVisible":
        let visible = (call.arguments as? Bool) ?? false
        self.setMenuBarVisible(visible)
        result(nil)
      case "update":
        guard let args = call.arguments as? [String: Any] else {
          result(nil)
          return
        }
        let bpm = args["bpm"] as? Int
        let connected = (args["connected"] as? Bool) ?? false
        self.updateMenuBarTitle(bpm: bpm, connected: connected)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setMenuBarVisible(_ visible: Bool) {
    if visible {
      if statusItem == nil {
        statusItem = NSStatusBar.system.statusItem(
          withLength: NSStatusItem.variableLength)
        buildMenuBarMenu()
        updateMenuBarTitle(bpm: nil, connected: false)
      }
    } else if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
  }

  private func buildMenuBarMenu() {
    let menu = NSMenu()
    let showMain = NSMenuItem(
      title: "显示主窗口",
      action: #selector(showMainWindow),
      keyEquivalent: "")
    let quit = NSMenuItem(
      title: "退出 PulseSight",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    menu.items = [showMain, .separator(), quit]
    statusItem?.menu = menu
  }

  @objc private func showMainWindow() {
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// 更新菜单栏标题:已连接显示红色 "♥ 72",未连接显示弱化的 "♥ --"。
  /// 心形用更大字号突出,数字保持 13pt 等宽。
  private func updateMenuBarTitle(bpm: Int?, connected: Bool) {
    guard let button = statusItem?.button else { return }
    let heartColor = connected
      ? NSColor.systemRed
      : NSColor.labelColor.withAlphaComponent(0.55)
    let textColor = connected
      ? NSColor.labelColor
      : NSColor.labelColor.withAlphaComponent(0.55)
    let text = (connected && bpm != nil) ? "\(bpm!)" : "--"

    let title = NSMutableAttributedString()
    title.append(
      NSAttributedString(
        string: "♥",
        attributes: [
          .font: NSFont.systemFont(ofSize: 16, weight: .medium),
          .foregroundColor: heartColor,
          .baselineOffset: -1,
        ]))
    title.append(NSAttributedString(string: " "))
    title.append(
      NSAttributedString(
        string: text,
        attributes: [
          .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
          .foregroundColor: textColor,
        ]))
    button.attributedTitle = title
  }

  /// 点关闭按钮(或 Cmd+W)仅隐藏主窗口,App 保持运行;
  /// 通过菜单栏「显示主窗口」或点击 Dock 图标恢复。
  override func performClose(_ sender: Any?) {
    orderOut(nil)
  }
}
