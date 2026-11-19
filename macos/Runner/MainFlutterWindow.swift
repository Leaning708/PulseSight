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
  /// 交通灯(关闭 / 最小化 / 缩放)的左侧起点。
  ///
  /// 默认位置约为 7pt。Flutter 顶栏红心左边距 16pt、直径 22pt,中心在 27pt。
  /// 纯几何对齐时关闭按钮起点应取 20pt;但红心是 22pt 的实心图形、交通灯
  /// 只是 12pt 的小圆点,视觉重心不同,需要微调:取 17pt 时关闭按钮中心在
  /// 24pt,灯组视觉重心落在红心左缘附近,平视不再「偏右」。
  private let trafficLightLeadingInset: CGFloat = 17

  /// 菜单栏心率显示的 NSStatusItem。
  private var statusItem: NSStatusItem?

  /// 状态项菜单中的显示端开关条目(按 Dart 侧 AppMenuToggle 键名索引)。
  private var appMenuItems: [String: NSMenuItem] = [:]

  /// 应用菜单通道(与 lib/data/services/platform/macos_app_menu_service.dart 对应)。
  private var appMenuChannel: FlutterMethodChannel?

  /// 应用菜单条目标识。
  private static let appMenuKeys = [
    "desktopOverlay", "mousePassthrough", "menubarHeart", "obsOverlay",
  ]

  /// 应用菜单条目标题。
  private static let appMenuTitles = [
    "桌面悬浮窗", "鼠标穿透", "菜单栏心率", "OBS 浏览器源",
  ]

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
    setupAppMenuChannel(with: flutterViewController.engine.binaryMessenger)
    SystemFontListSupport.register(with: flutterViewController.engine.binaryMessenger)

    setupAppearanceSync()

    super.awakeFromNib()

    // window_manager 在启动后应用 hidden title bar,AppKit 会重新布局
    // 交通灯;等下一轮 runloop 再对齐,并在窗口获得焦点 / 缩放 / 退出
    // 全屏后重新校正。
    DispatchQueue.main.async { [weak self] in
      self?.alignTrafficLights()
    }
    // setFrame 已做同步校正,这里的通知只兜底覆盖 didBecomeKey / 全屏退出
    // 这类不经过 setFrame 的 AppKit 重排。
    for name in [
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didExitFullScreenNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(windowLayoutChanged(_:)),
        name: name, object: self)
    }
  }

  @objc private func windowLayoutChanged(_ notification: Notification) {
    // 同步校正:若放进 next runloop,用户会先看到 AppKit 把按钮摆回默认
    // 位置、再被拉回来,这就是缩放窗口时红绿灯「抖一下」的来源。
    alignTrafficLights()
  }

  /// 窗口尺寸变化(拖拽缩放、最大化、全屏进出)时立即校正。
  ///
  /// AppKit 会给标准按钮重新排位,若等到 didResize 通知之后再 async 校正,
  /// 用户会先看到默认位置、再看到按钮被拉回——这就是「抖一下」。
  /// 重写 setFrame 后在同一次布局里完成定位,肉眼不可见。
  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    alignTrafficLights()
  }

  override func setFrame(
    _ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool
  ) {
    super.setFrame(frameRect, display: flag, animate: animateFlag)
    alignTrafficLights()
  }

  /// 将系统交通灯整体右移到内容区左边距,保持按钮之间的原始间距。
  private func alignTrafficLights() {
    // 全屏时系统会接管按钮位置,不再干预。
    guard !styleMask.contains(.fullScreen),
      let close = standardWindowButton(.closeButton),
      let minimize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton)
    else { return }

    let gap = minimize.frame.minX - close.frame.minX
    guard gap > 0 else { return }
    let y = close.frame.minY

    if abs(close.frame.minX - trafficLightLeadingInset) > 0.5 {
      close.setFrameOrigin(
        NSPoint(x: trafficLightLeadingInset, y: y))
    }
    let minimizeX = trafficLightLeadingInset + gap
    if abs(minimize.frame.minX - minimizeX) > 0.5 {
      minimize.setFrameOrigin(NSPoint(x: minimizeX, y: minimize.frame.minY))
    }
    let zoomX = minimizeX + gap
    if abs(zoom.frame.minX - zoomX) > 0.5 {
      zoom.setFrameOrigin(NSPoint(x: zoomX, y: zoom.frame.minY))
    }
  }

  /// 标题栏外观跟随应用主题模式。
  ///
  /// Flutter 侧的主题模式持久化在标准 UserDefaults 域
  /// (SharedPreferencesAsync,键 `app.theme_mode`),
  /// 这里通过 didChangeNotification 监听写入并同步窗口外观:
  /// dark/light 分别切换到 darkAqua/aqua,无值(跟随系统)清除覆盖。
  private var appearanceObserver: NSObjectProtocol?

  private func setupAppearanceSync() {
    syncWindowAppearance()
    appearanceObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.syncWindowAppearance()
    }
  }

  private func syncWindowAppearance() {
    switch UserDefaults.standard.string(forKey: "app.theme_mode") {
    case "dark":
      appearance = NSAppearance(named: .darkAqua)
    case "light":
      appearance = NSAppearance(named: .aqua)
    default:
      appearance = nil
    }
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
      appMenuItems.removeAll()
    }
  }

  /// 注册应用菜单通道:接收 Flutter 推送的开关状态;
  /// 条目点击经 toggle 转发回 Flutter,由 ViewModel 执行切换并回推。
  private func setupAppMenuChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pulsesight/app_menu",
      binaryMessenger: messenger)
    appMenuChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "update":
        guard let args = call.arguments as? [String: Any] else {
          result(nil)
          return
        }
        self.updateAppMenuStates(args)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 状态项菜单:显示端开关条目 + 主窗口控制。
  ///
  /// 构建后经 refresh 向 Flutter 请求当前状态——状态项可能在 VM 推送
  /// 之后才创建(如菜单栏心率被重新开启),勾选态需主动对齐。
  private func buildMenuBarMenu() {
    let menu = NSMenu()
    // 关闭自动启用,才能对单个条目做置灰(如悬浮窗关闭时的鼠标穿透)。
    menu.autoenablesItems = false
    for (index, key) in Self.appMenuKeys.enumerated() {
      let item = NSMenuItem(
        title: Self.appMenuTitles[index],
        action: #selector(appMenuItemToggled(_:)),
        keyEquivalent: "")
      item.tag = index
      item.target = self
      item.isEnabled = true
      item.state = .off
      menu.addItem(item)
      appMenuItems[key] = item
    }
    appMenuItems["mousePassthrough"]?.isEnabled = false
    menu.addItem(.separator())
    let showMain = NSMenuItem(
      title: "显示主窗口",
      action: #selector(showMainWindow),
      keyEquivalent: "")
    let quit = NSMenuItem(
      title: "退出 PulseSight",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    menu.addItem(showMain)
    menu.addItem(.separator())
    menu.addItem(quit)
    statusItem?.menu = menu
    appMenuChannel?.invokeMethod("refresh", arguments: nil)
  }

  /// 更新条目勾选 / 可用状态。
  private func updateAppMenuStates(_ args: [String: Any]) {
    func flag(_ key: String) -> Bool { (args[key] as? Bool) ?? false }
    NSLog(
      "[PulseSight] app menu updated: overlay=%d, passthrough=%d (enabled=%d), menubar=%d, obs=%d",
      flag("desktopOverlay") ? 1 : 0,
      flag("mousePassthrough") ? 1 : 0,
      flag("mousePassthroughEnabled") ? 1 : 0,
      flag("menubarHeart") ? 1 : 0,
      flag("obsOverlay") ? 1 : 0)
    setItem("desktopOverlay", checked: flag("desktopOverlay"), enabled: true)
    setItem(
      "mousePassthrough",
      checked: flag("mousePassthrough"),
      enabled: flag("desktopOverlay"))
    setItem("menubarHeart", checked: flag("menubarHeart"), enabled: true)
    setItem("obsOverlay", checked: flag("obsOverlay"), enabled: true)
  }

  private func setItem(_ key: String, checked: Bool, enabled: Bool) {
    guard let item = appMenuItems[key] else { return }
    item.state = checked ? .on : .off
    item.isEnabled = enabled
  }

  /// 条目点击:转发给 Flutter 侧,由 ViewModel 执行切换并回推新状态。
  @objc private func appMenuItemToggled(_ sender: NSMenuItem) {
    guard sender.tag >= 0, sender.tag < Self.appMenuKeys.count else { return }
    appMenuChannel?.invokeMethod(
      "toggle", arguments: ["key": Self.appMenuKeys[sender.tag]])
  }

  @objc private func showMainWindow() {
    self.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// 更新菜单栏标题:已连接显示红色 "♥ 72",未连接显示弱化的灰色 "♥ --"。
  /// 心形用更大字号突出,数字保持 13pt 等宽。
  /// 颜色用语义色(systemGray / secondaryLabelColor):状态项渲染 attributed
  /// 标题时会丢弃动态色的 alpha 分量(0.55 黑会变成纯黑),语义色稳定呈灰
  /// 且自适应深浅色外观。
  private func updateMenuBarTitle(bpm: Int?, connected: Bool) {
    guard let button = statusItem?.button else { return }
    let heartColor = connected ? NSColor.systemRed : NSColor.systemGray
    let textColor = connected ? NSColor.labelColor : NSColor.secondaryLabelColor
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

  deinit {
    if let appearanceObserver {
      NotificationCenter.default.removeObserver(appearanceObserver)
    }
    NotificationCenter.default.removeObserver(self)
  }
}
