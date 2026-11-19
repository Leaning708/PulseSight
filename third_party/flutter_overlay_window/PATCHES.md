# 本地补丁说明

本目录是 `flutter_overlay_window` 1.0.2 的内置副本(通过 `dependency_overrides`
生效),只为修复上游尚未处理的问题。除下列改动外与上游一致,升级上游时请优先
比对是否已修复,已修复则删除本目录并移除 override。

## 1. 旋转后悬浮窗边界仍按旧方向计算

- 现象:横屏时无法把悬浮窗拖到屏幕最左 / 最右(竖屏宽度成了右边界)。
- 原因:`OverlayService.szWindow` 只在 `onCreate` 读取一次。
- 修复:`refreshDisplayMetrics()` 按当前窗口度量刷新尺寸并失效系统栏缓存,
  在 `onConfigurationChanged` 与每次计算边界前调用。

## 2. 吸附行为无法运行时切换

- 需求:手机端「边缘吸附」需要做成开关。
- 修复:`OverlayService.setPositionGravity()` + 渠道方法 `setPositionGravity`,
  Dart 侧对应 `FlutterOverlayWindow.setPositionGravity()`。

## 3. 主界面调用 updateFlag 无效(触摸穿透开关)

- 现象:主界面点「触摸穿透」不生效,悬浮窗仍可拖动。
- 原因:Dart 侧用 `_overlayChannel`(x-slayer/overlay)发送,该通道只在悬浮窗
  服务(overlay 引擎)注册;主引擎没有该通道,调用被吞。
- 修复:Dart 侧改走主引擎通道,Activity 侧插件新增 `updateFlag` 转发到
  `OverlayService.setOverlayFlag()`。

## 4. 旋转后窗口可能落在屏幕外

- 修复:`onConfigurationChanged` 里按新边界重新夹取并回传位置。

## 5. 拖动结束后不回传位置

- 需求:悬浮窗需要记住上次位置。
- 修复:拖动结束与吸附动画结束时,经 overlay 消息通道回传
  `{type: 'overlay_position', x, y}`(逻辑像素)。
