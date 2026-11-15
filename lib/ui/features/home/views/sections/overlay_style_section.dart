import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../../../domain/models/overlay_style.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/setting_row.dart';
import '../../../overlay/views/overlay_view.dart';
import '../../view_models/home_view_model.dart';

/// 预览与控件并排布局所需的最小可用宽度;低于该值上下堆叠。
const double overlayStyleSideBySideMinWidth = 560;

/// 悬浮窗样式设置区内容:实时预览与全部样式调节(不含标题)。
///
/// 可用宽度达到 [overlayStyleSideBySideMinWidth] 时预览左置、
/// 控件右置,否则预览在上、控件在下。
class OverlayStyleSection extends StatelessWidget {
  /// 创建样式设置区;[viewModel] 由上层注入。
  const OverlayStyleSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  /// 窄布局(手机形态)下的预览舞台宽度。
  static const double _previewWidth = 170;

  /// 窄布局下的预览舞台高度。
  static const double _previewHeight = 210;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide =
                constraints.maxWidth >= overlayStyleSideBySideMinWidth;
            final preview = OverlayStylePreview(
              viewModel: viewModel,
              width: _previewWidth,
              height: _previewHeight,
              caption: '预览(实际悬浮窗为透明背景)',
            );
            final controls = OverlayStyleControls(viewModel: viewModel);
            if (!sideBySide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  preview,
                  const SizedBox(height: AppSpacing.lg),
                  controls,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _previewWidth, child: preview),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: controls),
              ],
            );
          },
        );
      },
    );
  }
}

/// 深色舞台预览:内嵌真实悬浮窗内容,与实际观感一致。
///
/// 内部读取 [viewModel] 的连接状态 / bpm / 样式,调用方需处于
/// viewModel 的 [ListenableBuilder] 监听范围内。
class OverlayStylePreview extends StatelessWidget {
  /// 创建预览;[width] / [height] 为舞台尺寸,[caption] 可选说明文字。
  const OverlayStylePreview({
    super.key,
    required this.viewModel,
    required this.width,
    required this.height,
    this.caption,
  });

  final HomeViewModel viewModel;

  final double width;

  final double height;

  /// 预览下方的说明文字;null 时不渲染。
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.stageColor,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.2)),
          ),
          child: OverlayView(
            bpm: connected ? viewModel.bpm : null,
            connected: connected,
            style: viewModel.overlayStyle,
            history: viewModel.heartRateHistory,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// 悬浮窗样式调节控件:按「尺寸与布局 / 颜色 / 图表 / 动效与文字」
/// 四组呈现(不含标题与预览),供窄布局与桌面样式页共用。
class OverlayStyleControls extends StatelessWidget {
  /// 创建样式控件;[viewModel] 由上层注入。
  const OverlayStyleControls({super.key, required this.viewModel});

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final style = viewModel.overlayStyle;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _layoutGroup(context, style),
            const SizedBox(height: AppSpacing.xxl),
            _colorGroup(context, style),
            const SizedBox(height: AppSpacing.xxl),
            _chartGroup(context, style),
            const SizedBox(height: AppSpacing.xxl),
            _motionTextGroup(context, style),
          ],
        );
      },
    );
  }

  /// 「尺寸与布局」组:大小、间距、透明度与数字位置。
  Widget _layoutGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '尺寸与布局',
      children: [
        ..._spaced([
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
            labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
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
        ]),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '数字位置'),
        const SizedBox(height: AppSpacing.xs + 2),
        SegmentedButton<BpmPosition>(
          segments: _bpmPositionLabels.entries
              .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
              .toList(),
          selected: {style.bpmPosition},
          onSelectionChanged: (selection) {
            viewModel.setOverlayBpmPosition(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _toggleRow(
          '显示 bpm 标签',
          '心率数字旁的 “bpm” 小字',
          style.showBpmLabel,
          viewModel.setOverlayShowBpmLabel,
        ),
      ],
    );
  }

  /// 「颜色」组:背景板 / 心脏 / 心电图 / 文字的预设色板。
  Widget _colorGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '颜色',
      children: _spaced([
        _colorSwatchRow(
          context: context,
          label: '背景板颜色',
          current: style.backgroundColor,
          presets: _backgroundColorSwatches,
          onPicked: viewModel.setOverlayBackgroundColor,
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
      ]),
    );
  }

  /// 「图表」组:心率折线图的开关、尺寸与配色。
  Widget _chartGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '图表',
      children: [
        ..._spaced([
          _toggleRow(
            '心率折线图',
            '在悬浮窗底部绘制近期心率波动曲线',
            style.showChart,
            viewModel.setOverlayShowChart,
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
        ]),
        const SizedBox(height: AppSpacing.md),
        _colorSwatchRow(
          context: context,
          label: '折线图颜色',
          current: style.chartLineColor,
          presets: _chartLineColorSwatches,
          onPicked: viewModel.setOverlayChartLineColor,
        ),
      ],
    );
  }

  /// 「动效与文字」组:律动、辉光、心电图样式与字体。
  Widget _motionTextGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '动效与文字',
      children: [
        ..._spaced([
          _toggleRow(
            '心形律动',
            '关闭后心形静止(心电图动画照常)',
            style.heartPulseEnabled,
            viewModel.setOverlayHeartPulseEnabled,
          ),
          _toggleRow(
            '文字律动',
            '关闭后心率数字静止',
            style.textPulseEnabled,
            viewModel.setOverlayTextPulseEnabled,
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
        ]),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '心电图样式'),
        const SizedBox(height: AppSpacing.xs + 2),
        SegmentedButton<EcgStyle>(
          segments: _ecgStyleLabels.entries
              .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
              .toList(),
          selected: {style.ecgStyle},
          onSelectionChanged: (selection) {
            viewModel.setOverlayEcgStyle(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '字重'),
        const SizedBox(height: AppSpacing.xs + 2),
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
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '字体'),
        const SizedBox(height: AppSpacing.xs + 2),
        DropdownButton<String?>(
          value: style.textFontFamily,
          isExpanded: true,
          // Windows 字体族上百个,限制菜单高度避免全屏弹出。
          menuMaxHeight: 400,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('默认(系统)')),
            ...viewModel.overlayFontFamilies.map(
              (family) => DropdownMenuItem<String?>(
                value: family,
                child: Text(family, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (family) => viewModel.setOverlayTextFontFamily(family),
        ),
      ],
    );
  }

  /// 一组控件:组标题 + 组内条目(条目间距由调用方在 children 中自行安排)。
  Widget _group(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }

  /// 字段标签。
  Widget _fieldLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }

  /// 带开关的设置行。
  Widget _toggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SettingRow(
      title: title,
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  /// 在列表元素之间插入 [AppSpacing.md] 垂直间距。
  List<Widget> _spaced(Iterable<Widget> items) {
    final result = <Widget>[];
    var first = true;
    for (final item in items) {
      if (!first) result.add(const SizedBox(height: AppSpacing.md));
      result.add(item);
      first = false;
    }
    return result;
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
                          : Theme.of(context).colorScheme.onSurface
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
                        : Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface
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
    BuildContext context,
    Color initial,
    String title,
  ) async {
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
}

/// 带标签与实时数值的样式滑块。
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

  /// 数值文案;缺省为四舍五入整数,同时用于拖动提示与尾部实时显示。
  final String Function(double value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final text = labelBuilder?.call(value) ?? value.round().toString();
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            label: text,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 52,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
