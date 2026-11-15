import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/heart_rate_connection.dart';
import '../../../../domain/models/overlay_style.dart';
import '../view_models/home_view_model.dart';
import '../../../core/widgets/bpm_display.dart';
import '../../../core/widgets/heartbeat_heart.dart';
import '../../overlay/views/overlay_view.dart';

/// 主界面:连接管理 + 各显示端开关。
class HomeView extends StatelessWidget {
  /// 创建主界面;[viewModel] 由 DI 注入。
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PulseSight')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 24),
                  _ConnectionSection(viewModel: viewModel),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 4),
                  _DisplayTogglesSection(viewModel: viewModel),
                  if (viewModel.supportsDesktopOverlay ||
                      viewModel.supportsAndroidDisplay) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    _OverlayStyleSection(viewModel: viewModel),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '当前使用模拟数据源,小米手环蓝牙广播连接将在后续版本提供。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 连接状态区:红心、bpm、状态徽标与连接按钮。
class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({required this.viewModel});

  final HomeViewModel viewModel;

  String get _statusLabel {
    return switch (viewModel.connection) {
      HeartRateConnection.connected => '已连接(模拟)',
      HeartRateConnection.connecting => '正在连接…',
      HeartRateConnection.disconnected => '未连接',
    };
  }

  Color _statusColor(ColorScheme scheme) {
    return switch (viewModel.connection) {
      HeartRateConnection.connected => Colors.green.shade600,
      HeartRateConnection.connecting => Colors.orange.shade600,
      HeartRateConnection.disconnected => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
    return Column(
      children: [
        HeartbeatHeart(size: 180, bpm: connected ? viewModel.bpm : null),
        const SizedBox(height: 16),
        BpmDisplay(
          bpm: connected ? viewModel.bpm : null,
          numberStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 12),
        Chip(
          avatar: CircleAvatar(
            radius: 5,
            backgroundColor: _statusColor(scheme),
          ),
          label: Text(_statusLabel),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: viewModel.canConnect
              ? () => viewModel.connect()
              : () => viewModel.disconnect(),
          icon: Icon(
            viewModel.canConnect ? Icons.monitor_heart_outlined : Icons.link_off,
          ),
          label: Text(viewModel.canConnect ? '连接手环(模拟)' : '断开连接'),
        ),
      ],
    );
  }
}

/// 显示端开关区:按平台能力渲染对应开关。
class _DisplayTogglesSection extends StatelessWidget {
  const _DisplayTogglesSection({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (viewModel.supportsDesktopOverlay) ...[
        SwitchListTile(
          secondary: const Icon(Icons.open_with),
          title: const Text('桌面悬浮窗'),
          subtitle: const Text('在桌面悬浮显示实时心率,关闭穿透后可拖动'),
          value: viewModel.desktopOverlayEnabled,
          onChanged: (value) => viewModel.setDesktopOverlayEnabled(value),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.mouse),
          title: const Text('鼠标穿透'),
          subtitle: const Text('开启后点击会穿透悬浮窗作用于下层内容'),
          value: viewModel.mousePassthroughEnabled,
          onChanged: viewModel.desktopOverlayEnabled
              ? (value) => viewModel.setMousePassthroughEnabled(value)
              : null,
        ),
      ],
      if (viewModel.supportsMenubar)
        SwitchListTile(
          secondary: const Icon(Icons.favorite_border),
          title: const Text('菜单栏心率'),
          subtitle: const Text('在系统菜单栏实时显示当前心率'),
          value: viewModel.menubarEnabled,
          onChanged: (value) => viewModel.setMenubarEnabled(value),
        ),
      if (viewModel.supportsAndroidDisplay) ...[
        SwitchListTile(
          secondary: const Icon(Icons.picture_in_picture_alt),
          title: const Text('心率悬浮窗'),
          subtitle: const Text('在其他应用上层悬浮显示实时心率,可拖动'),
          value: viewModel.androidOverlayEnabled,
          onChanged: (value) async {
            final ok = await viewModel.setAndroidOverlayEnabled(value);
            if (!ok && context.mounted) {
              _showSnackBar(context, '未授予悬浮窗权限,请在系统设置中开启');
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('状态栏心率'),
          subtitle: const Text('通过持续通知展示当前心率'),
          value: viewModel.statusBarEnabled,
          onChanged: (value) async {
            final ok = await viewModel.setStatusBarEnabled(value);
            if (!ok && context.mounted) {
              _showSnackBar(context, '未授予通知权限,无法在状态栏展示');
            }
          },
        ),
      ],
    ];
    return Column(children: tiles);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 悬浮窗样式设置区:实时预览 + 心形大小/数字大小/位置/心电图样式/间距调节。
class _OverlayStyleSection extends StatelessWidget {
  const _OverlayStyleSection({required this.viewModel});

  final HomeViewModel viewModel;

  static const _bpmPositionLabels = <BpmPosition, String>{
    BpmPosition.top: '上',
    BpmPosition.bottom: '下',
    BpmPosition.left: '左',
    BpmPosition.right: '右',
    BpmPosition.hidden: '隐藏',
  };

  static const _ecgStyleLabels = <EcgStyle, String>{
    EcgStyle.none: '关',
    EcgStyle.flat: '直线',
    EcgStyle.single: '单峰',
    EcgStyle.classic: '经典',
    EcgStyle.digits: '数字',
  };

  /// 背景板预设色板(均为深色系,保证浅色文字可读)。
  static const List<Color> _backgroundColorSwatches = [
    Color(0xFF17181C), // 深灰(默认)
    Color(0xFF000000), // 黑
    Color(0xFF1A237E), // 深蓝
    Color(0xFF4A148C), // 深紫
    Color(0xFFB71C1C), // 深红
    Color(0xFF1B5E20), // 深绿
    Color(0xFF3E2723), // 深棕
    Color(0xFF37474F), // 蓝灰
  ];

  /// 折线图预设色板(心率红默认,浅色系备选)。
  static const List<Color> _chartLineColorSwatches = [
    Color(0xFFE23A3A), // 心率红(默认)
    Color(0xFFFFFFFF), // 白
    Color(0xFFFFD54F), // 金
    Color(0xFF4DD0E1), // 青
    Color(0xFFF48FB1), // 粉
    Color(0xFFA5D6A7), // 浅绿
    Color(0xFFB0BEC5), // 浅灰
    Color(0xFF212121), // 黑
  ];

  /// 心形预设色板。
  static const List<Color> _heartColorSwatches = [
    Color(0xFFE23A3A), // 红(默认)
    Color(0xFFFF6B81), // 粉红
    Color(0xFFFF7043), // 橙
    Color(0xFFAB47BC), // 紫
    Color(0xFF29B6F6), // 蓝
    Color(0xFF66BB6A), // 绿
    Color(0xFFFFC107), // 金
    Color(0xFF212121), // 黑
  ];

  /// 心电图线/文字预设色板(浅色为主,深底上清晰)。
  static const List<Color> _lineColorSwatches = [
    Color(0xFFFFFFFF), // 白(默认)
    Color(0xFFFFD54F), // 金
    Color(0xFF4DD0E1), // 青
    Color(0xFFF48FB1), // 粉
    Color(0xFFA5D6A7), // 浅绿
    Color(0xFFFF5252), // 红
    Color(0xFFB0BEC5), // 浅灰
    Color(0xFF212121), // 黑
  ];

  /// 将字重数值映射到最接近的字重分段档位(300/400/600/800/900)。
  static double _fontWeightSegment(double weight) {
    const stops = [300.0, 400.0, 600.0, 800.0, 900.0];
    var nearest = stops.first;
    for (final stop in stops.skip(1)) {
      if ((weight - stop).abs() < (weight - nearest).abs()) {
        nearest = stop;
      }
    }
    return nearest;
  }

  /// 生成一行颜色色板 + 自定义选色入口。
  Widget _colorSwatchRow({
    required BuildContext context,
    required String label,
    required Color current,
    required List<Color> presets,
    required ValueChanged<Color> onPicked,
  }) {
    final isCustom = !presets.contains(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in presets)
              GestureDetector(
                onTap: () => onPicked(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: current == color ? 3 : 1,
                      color: current == color
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            // 自定义颜色:打开调色盘对话框;当前为自定义色时高亮。
            GestureDetector(
              onTap: () async {
                final picked = await _pickColor(context, current, label);
                if (picked != null) onPicked(picked);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: isCustom ? 3 : 1,
                    color: isCustom
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 打开自定义颜色选择器对话框;确定后返回所选颜色。
  Future<Color?> _pickColor(
      BuildContext context, Color initial, String title) async {
    Color temp = initial;
    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('自定义$title'),
        content: SingleChildScrollView(
          // ColorPicker 内部的格式下拉按钮需要 Material 祖先。
          child: Material(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ColorPicker(
                pickerColor: temp,
                onColorChanged: (color) => temp = color,
                paletteType: PaletteType.hueWheel,
                pickerAreaHeightPercent: 0.75,
                displayThumbColor: true,
                enableAlpha: false, // 透明度由独立滑块控制
                labelTypes: const [], // 禁用 rgb/hsv/hsl 标签行(其下拉按钮在桌面端触发 LookupBoundary 查找异常)
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, temp),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final style = viewModel.overlayStyle;
        final connected =
            viewModel.connection == HeartRateConnection.connected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('悬浮窗样式',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              '更改实时生效并自动保存(需打开上方悬浮窗开关查看)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 12),
            // 实时预览:按当前样式渲染悬浮窗内容。
            Center(
              child: Container(
                width: 170,
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFF17181C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: OverlayView(
                  bpm: connected ? viewModel.bpm : null,
                  connected: connected,
                  style: style,
                  history: viewModel.heartRateHistory,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '预览(实际悬浮窗为透明背景)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            _StyleSlider(
              label: '心形大小',
              value: style.heartSize,
              min: 36,
              max: 96,
              divisions: 15,
              onChanged: viewModel.setOverlayHeartSize,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '数字大小',
              value: style.bpmFontSize,
              min: 12,
              max: 36,
              divisions: 12,
              onChanged: viewModel.setOverlayBpmFontSize,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '间距',
              value: style.gap,
              min: 0,
              max: 24,
              divisions: 12,
              onChanged: viewModel.setOverlayGap,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '心率透明度',
              value: style.opacity,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              labelBuilder: (v) => '${(v * 100).round()}%',
              onChanged: viewModel.setOverlayOpacity,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '背景板透明度',
              value: style.backgroundOpacity,
              min: 0,
              max: 1.0,
              divisions: 10,
              labelBuilder: (v) =>
                  v <= 0 ? '无' : '${(v * 100).round()}%',
              onChanged: viewModel.setOverlayBackgroundOpacity,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '背景板宽度',
              value: style.backgroundWidth,
              min: 100,
              max: 240,
              divisions: 14,
              onChanged: viewModel.setOverlayBackgroundWidth,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '背景板高度',
              value: style.backgroundHeight,
              min: 120,
              max: 280,
              divisions: 16,
              onChanged: viewModel.setOverlayBackgroundHeight,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('心形律动'),
              subtitle: const Text('关闭后心形静止(心电图动画照常)'),
              value: style.heartPulseEnabled,
              onChanged: viewModel.setOverlayHeartPulseEnabled,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('文字律动'),
              subtitle: const Text('关闭后心率数字静止'),
              value: style.textPulseEnabled,
              onChanged: viewModel.setOverlayTextPulseEnabled,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('心率折线图'),
              subtitle: const Text('在悬浮窗底部绘制近期心率波动曲线'),
              value: style.showChart,
              onChanged: viewModel.setOverlayShowChart,
            ),
            _StyleSlider(
              label: '辉光透明度',
              value: style.glowOpacity,
              min: 0,
              max: 1.0,
              divisions: 10,
              labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
              onChanged: viewModel.setOverlayGlowOpacity,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '辉光半径',
              value: style.glowRadius,
              min: 0,
              max: 3.0,
              divisions: 12,
              labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
              onChanged: viewModel.setOverlayGlowRadius,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            const SizedBox(height: 4),
            _colorSwatchRow(
              context: context,
              label: '背景板颜色',
              current: style.backgroundColor,
              presets: _backgroundColorSwatches,
              onPicked: viewModel.setOverlayBackgroundColor,
            ),
            _colorSwatchRow(
              context: context,
              label: '折线图颜色',
              current: style.chartLineColor,
              presets: _chartLineColorSwatches,
              onPicked: viewModel.setOverlayChartLineColor,
            ),
            _StyleSlider(
              label: '采集时长',
              value: style.chartSeconds,
              min: 10,
              max: 120,
              divisions: 11,
              labelBuilder: (v) => '${v.round()} 秒',
              onChanged: viewModel.setOverlayChartSeconds,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '折线图高度',
              value: style.chartHeight,
              min: 40,
              max: 160,
              divisions: 12,
              onChanged: viewModel.setOverlayChartHeight,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _StyleSlider(
              label: '图表间距',
              value: style.chartSpacing,
              min: 0,
              max: 24,
              divisions: 12,
              onChanged: viewModel.setOverlayChartSpacing,
              onChangeEnd: (_) => viewModel.persistOverlayStyle(),
            ),
            _colorSwatchRow(
              context: context,
              label: '心脏颜色',
              current: style.heartColor,
              presets: _heartColorSwatches,
              onPicked: viewModel.setOverlayHeartColor,
            ),
            _colorSwatchRow(
              context: context,
              label: '心电图颜色',
              current: style.ecgColor,
              presets: _lineColorSwatches,
              onPicked: viewModel.setOverlayEcgColor,
            ),
            _colorSwatchRow(
              context: context,
              label: '文字颜色',
              current: style.textColor,
              presets: _lineColorSwatches,
              onPicked: viewModel.setOverlayTextColor,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('显示 bpm 标签'),
              subtitle: const Text('心率数字旁的 “bpm” 小字'),
              value: style.showBpmLabel,
              onChanged: viewModel.setOverlayShowBpmLabel,
            ),
            const SizedBox(height: 4),
            Text('字重', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 300, label: Text('细')),
                ButtonSegment(value: 400, label: Text('常规')),
                ButtonSegment(value: 600, label: Text('中粗')),
                ButtonSegment(value: 800, label: Text('粗')),
                ButtonSegment(value: 900, label: Text('特粗')),
              ],
              selected: {_fontWeightSegment(style.textWeight)},
              onSelectionChanged: (selection) =>
                  viewModel.setOverlayTextWeight(selection.first),
            ),
            const SizedBox(height: 12),
            Text('字体', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            DropdownButton<String?>(
              value: style.textFontFamily,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('默认(系统)'),
                ),
                ...viewModel.overlayFontFamilies.map(
                  (family) => DropdownMenuItem<String?>(
                    value: family,
                    child: Text(family, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (family) => viewModel.setOverlayTextFontFamily(family),
            ),
            const SizedBox(height: 4),
            Text('数字位置', style: Theme.of(context).textTheme.labelLarge),
            SegmentedButton<BpmPosition>(
              segments: _bpmPositionLabels.entries
                  .map((e) => ButtonSegment(
                        value: e.key,
                        label: Text(e.value),
                      ))
                  .toList(),
              selected: {style.bpmPosition},
              onSelectionChanged: (selection) {
                viewModel.setOverlayBpmPosition(selection.first);
              },
            ),
            const SizedBox(height: 12),
            Text('心电图样式', style: Theme.of(context).textTheme.labelLarge),
            SegmentedButton<EcgStyle>(
              segments: _ecgStyleLabels.entries
                  .map((e) => ButtonSegment(
                        value: e.key,
                        label: Text(e.value),
                      ))
                  .toList(),
              selected: {style.ecgStyle},
              onSelectionChanged: (selection) {
                viewModel.setOverlayEcgStyle(selection.first);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// 带标签的样式滑块。
class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
    this.labelBuilder,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// 刻度数;null 时由区间长度推导(仅适用于整数区间)。
  final int? divisions;

  /// 拖动时显示的数值文案;缺省为四舍五入整数。
  final String Function(double value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            label: labelBuilder?.call(value) ?? value.round().toString(),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
