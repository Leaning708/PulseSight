import 'package:flutter/services.dart';

/// 应用菜单可切换的显示端条目。
enum AppMenuToggle {
  /// 桌面悬浮窗。
  desktopOverlay,

  /// 鼠标穿透(需桌面悬浮窗开启)。
  mousePassthrough,

  /// macOS 菜单栏心率。
  menubarHeart,

  /// OBS 浏览器源。
  obsOverlay,
}

/// 应用菜单开关条目的状态快照。
class AppMenuStates {
  /// 创建状态快照;[mousePassthroughEnabled] 表示鼠标穿透条目是否可用。
  const AppMenuStates({
    required this.desktopOverlay,
    required this.mousePassthrough,
    required this.mousePassthroughEnabled,
    required this.menubarHeart,
    required this.obsOverlay,
  });

  /// 桌面悬浮窗勾选态。
  final bool desktopOverlay;

  /// 鼠标穿透勾选态(条目不可用时该值不生效)。
  final bool mousePassthrough;

  /// 鼠标穿透条目是否可用(需桌面悬浮窗开启)。
  final bool mousePassthroughEnabled;

  /// 菜单栏心率勾选态。
  final bool menubarHeart;

  /// OBS 浏览器源勾选态。
  final bool obsOverlay;

  @override
  bool operator ==(Object other) =>
      other is AppMenuStates &&
      other.desktopOverlay == desktopOverlay &&
      other.mousePassthrough == mousePassthrough &&
      other.mousePassthroughEnabled == mousePassthroughEnabled &&
      other.menubarHeart == menubarHeart &&
      other.obsOverlay == obsOverlay;

  @override
  int get hashCode => Object.hash(
    desktopOverlay,
    mousePassthrough,
    mousePassthroughEnabled,
    menubarHeart,
    obsOverlay,
  );
}

/// 桌面应用菜单接口,便于 ViewModel 测试时替换。
abstract interface class AppMenuDisplay {
  /// 推送最新开关状态到菜单(仅在实际开关变化时被调用,无需去重)。
  Future<void> update(AppMenuStates states);

  /// 注册菜单条目点击回调;传 null 取消。
  void setToggleHandler(void Function(AppMenuToggle toggle)? handler);

  /// 注册状态刷新请求回调(原生菜单重建时请求对齐勾选态);传 null 取消。
  void setRefreshHandler(void Function()? handler);

  /// 释放资源。
  void dispose();
}

/// macOS 应用菜单服务:菜单栏状态项菜单中的显示端开关条目。
///
/// 经原生端([MainFlutterWindow.swift])注册的 `pulsesight/app_menu`
/// MethodChannel 双向通信:Flutter 推送勾选 / 可用状态,原生把条目
/// 点击与菜单重建时的刷新请求转发回来,由 ViewModel 执行与开关行
/// 等价的切换动作或重新推送当前状态。
class MacosAppMenuService implements AppMenuDisplay {
  static const MethodChannel _channel = MethodChannel('pulsesight/app_menu');

  void Function(AppMenuToggle)? _handler;

  void Function()? _refreshHandler;

  @override
  void setToggleHandler(void Function(AppMenuToggle toggle)? handler) {
    _handler = handler;
    _updateChannelHandler();
  }

  @override
  void setRefreshHandler(void Function()? handler) {
    _refreshHandler = handler;
    _updateChannelHandler();
  }

  void _updateChannelHandler() {
    _channel.setMethodCallHandler(
      (_handler == null && _refreshHandler == null) ? null : _onMethodCall,
    );
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'toggle':
        final toggle = _toggleFromKey(
          (call.arguments as Map?)?['key'] as String?,
        );
        if (toggle != null) {
          _handler?.call(toggle);
        }
      case 'refresh':
        _refreshHandler?.call();
    }
    return null;
  }

  AppMenuToggle? _toggleFromKey(String? key) => switch (key) {
    'desktopOverlay' => AppMenuToggle.desktopOverlay,
    'mousePassthrough' => AppMenuToggle.mousePassthrough,
    'menubarHeart' => AppMenuToggle.menubarHeart,
    'obsOverlay' => AppMenuToggle.obsOverlay,
    _ => null,
  };

  @override
  Future<void> update(AppMenuStates states) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'desktopOverlay': states.desktopOverlay,
        'mousePassthrough': states.mousePassthrough,
        'mousePassthroughEnabled': states.mousePassthroughEnabled,
        'menubarHeart': states.menubarHeart,
        'obsOverlay': states.obsOverlay,
      });
    } on MissingPluginException {
      // 原生端尚未注册(非 macOS 或窗口未就绪),忽略。
    }
  }

  @override
  void dispose() {
    _handler = null;
    _refreshHandler = null;
    _channel.setMethodCallHandler(null);
  }
}
