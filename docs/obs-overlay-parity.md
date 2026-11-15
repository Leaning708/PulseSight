# 悬浮窗与 OBS 浏览器源页面的同步维护对照

OBS 浏览器源叠加页(`lib/data/services/platform/obs_overlay_page.dart`,内嵌 HTML/JS)是对 Flutter 端悬浮窗视觉逻辑的**手工移植**。两端必须保持视觉与行为一致:

> ⚠️ **维护规则:修改 Flutter 端下列任何视觉逻辑时,必须同步修改页面端对应函数**(页面源码注释已标注 Flutter 来源),并按文末清单完成两端验证。反之亦然。

## 对照表

| 视觉 / 行为 | Flutter 端(事实来源) | OBS 页面端(移植) | 同步要点 |
| --- | --- | --- | --- |
| 心形路径 / 渐变 / 高光 | `ui/core/widgets/heartbeat_heart.dart` `_HeartPainter` | 页面 `<svg>` path / gradient / ellipse | 改路径数据需同步 SVG `d` 与 viewBox |
| 脉冲缩放序列(18/32/50 权重 + 缓动) | `ui/core/widgets/heartbeat_pulse.dart` `pulseSequence` | JS `pulseScale` | 权重、峰值 1.22、缓动曲线两端一致 |
| 心跳周期 = 60s/bpm;1 bpm = 每分钟一拍 | `HeartbeatPulse.beatDuration` + bpm 变化重启 repeat | JS 帧循环 `60000 / bpm` | 页面端相位连续推进,天然等效重启语义 |
| ECG 波形数学(cos 圆顶波,五样式) | `heartbeat_heart.dart` `_ecgWave` / `_bump` | JS `ecgWave` / `bump` | classic/single/flat/none/digits 参数逐一对应 |
| ECG 绘制节奏(0–45% 画出 / 60–90% 淡出) | `heartbeat_heart.dart` `ecgDrawInfo` | JS `ecgDrawInfo` | **相位 0 必须返回 null**:零长度路径描边会渲染成起点白点伪影 |
| 心形大小映射(s = size/20 × 0.94) | `heartbeat_heart.dart` `layoutFor` | JS `heartSize * 0.94` | 缩放系数变更需同步 |
| 心形律动关闭 → 心形静止、ECG 照常动画 | `OverlayStyle.heartPulseEnabled` + `OverlayView` 实时相位 | JS `pulseScale` 门控 + 实时相位 | 关律动 ≠ 冻结相位(冻结会让 ECG 隐形并残留白点) |
| 未连接灰心 | `ui/core/theme/app_theme.dart` `heartIdle`(0xFF9E9E9E) | JS `HEART_IDLE` | 颜色变更同步;灰心时不绘制 ECG |
| 折线图(Y 轴 min/max ±5、跨度 ≥20、网格/面积/末端点) | `ui/core/widgets/heart_rate_chart.dart` `_HeartRateChartPainter` | JS `drawChart` | 页面端 X 轴向内收 5px(canvas 裁切末端点;Flutter 端靠外边距容纳) |
| 数字字体 / 字重 / 阴影 / tabular-nums | `overlay_view.dart` numberStyle | JS `applyStyle` 数字段 | 新增文字样式字段两端同步 |
| bpmPosition 布局与 hidden 语义(hidden = 仅心形) | `overlay_view.dart` build switch | JS `applyStyle` 排序段 | 位置枚举增删两端同步 |
| 折线图开启时内容底部对齐(间距即实际间距) | `overlay_view.dart` `Align.bottomCenter` | CSS `#contentArea.with-chart` | 切勿改回垂直居中(会产生额外空隙) |
| 辉光(双层模糊,随脉冲扩张变化) | `_HeartPainter` 辉光段 | JS `drop-shadow` 段 | 页面端为近似等效,公式改动需目视复核 |
| 内容不透明度与背景板分离 | `overlay_view.dart` `Opacity` + Container | CSS `#content.style.opacity` / panel 背景 | 两套透明度独立调节 |

## 新增 OverlayStyle 字段的操作清单

1. `lib/domain/models/overlay_style.dart`:加字段 + `toJson` + `copyWith` + 默认值
2. `home_view_model.dart`:读取持久化值(`loadAll` / `persistOverlayStyle`)
3. `home_view.dart` `_OverlayStyleSection`:调节控件
4. **`obs_overlay_page.dart` `applyStyle`:新增对应 CSS/DOM 应用逻辑**(`toJson` 会自动带出新字段,页面端不消费即等于无效)
5. 两端测试 + 目视对比(应用悬浮窗预览 vs 浏览器打开浏览器源 URL)

## 验证方式

主界面开启「OBS 浏览器源」→ 浏览器打开显示的 URL(默认 `http://127.0.0.1:9423/`)→ 与应用内悬浮窗实时预览并排对比:连接态红心脉冲、ECG 各样式、样式调节实时生效、断开灰心。
