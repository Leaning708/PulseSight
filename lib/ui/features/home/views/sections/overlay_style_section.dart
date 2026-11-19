import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../../../domain/models/overlay_style.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/font_family_field.dart';
import '../../../../core/widgets/setting_row.dart';
import '../../../overlay/views/overlay_view.dart';
import '../../view_models/home_view_model.dart';

/// 预览与控件并排布局所需的最小可用宽度;低于该值只渲染控件。
const double overlayStyleSideBySideMinWidth = 560;

/// 悬浮窗样式设置区内容(不含标题)。
///
/// 手机等窄屏只渲染调节控件——移动端界面本身已能看到实际悬浮窗效果,
/// 再放一块预览既占地方又容易与实际悬浮窗混淆。
class OverlayStyleSection extends StatelessWidget {
  /// 创建样式设置区;[viewModel] 由上层注入。
  const OverlayStyleSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return OverlayStyleControls(viewModel: viewModel);
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
            style: viewModel.resolvedOverlayStyle,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _shapeGroup(context, style),
            const SizedBox(height: AppSpacing.xl),
            _textGroup(context, style),
            const SizedBox(height: AppSpacing.xl),
            _ecgGroup(context, style),
            const SizedBox(height: AppSpacing.xl),
            _backgroundGroup(context, style),
            const SizedBox(height: AppSpacing.xl),
            _glowGroup(context, style),
            const SizedBox(height: AppSpacing.xl),
            _chartGroup(context, style),
          ],
        );
      },
    );
  }

  /// 「图形」组:心形本体的大小、透明度、间距、配色与律动。
  Widget _shapeGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '图形',
      children: [
        ..._spaced([
          _StyleSlider(
            label: '大小',
            value: style.heartSize,
            min: 36,
            max: 96,
            divisions: 15,
            onChanged: viewModel.setOverlayHeartSize,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            label: '透明度',
            value: style.contentOpacity,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            labelBuilder: (v) => '${(v * 100).round()}%',
            onChanged: viewModel.setOverlayContentOpacity,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            label: '间距',
            value: style.heartTextGap,
            min: 0,
            max: 24,
            divisions: 12,
            onChanged: viewModel.setOverlayHeartTextGap,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _colorSwatchRow(
          context: context,
          id: 'heart',
          label: '颜色',
          current: style.heartColor,
          presets: _heartColorSwatches,
          onPicked: viewModel.setOverlayHeartColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        _toggleRow(
          '律动',
          '关闭后心形静止(心电图动画照常)',
          style.heartPulseEnabled,
          viewModel.setOverlayHeartPulseEnabled,
        ),
      ],
    );
  }

  /// 「文字」组:心率数字的位置、大小、配色、字重字体与律动。
  Widget _textGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '文字',
      children: [
        ..._spaced([
          _StyleSlider(
            label: '大小',
            value: style.bpmFontSize,
            min: 12,
            max: 36,
            divisions: 12,
            onChanged: viewModel.setOverlayBpmFontSize,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '位置'),
        const SizedBox(height: AppSpacing.xs + 2),
        SegmentedButton<BpmPosition>(
          segments: _bpmPositionLabels.entries
              .map(
                (e) => ButtonSegment(
                  value: e.key,
                  label: Text(e.value, maxLines: 1, softWrap: false),
                ),
              )
              .toList(),
          selected: {style.bpmPosition},
          showSelectedIcon: false,
          style: _segmentedStyle(context),
          onSelectionChanged: (selection) =>
              viewModel.setOverlayBpmPosition(selection.first),
        ),
        const SizedBox(height: AppSpacing.md),
        _colorSwatchRow(
          context: context,
          id: 'text',
          label: '颜色',
          current: style.bpmColor,
          presets: _lineColorSwatches,
          onPicked: viewModel.setOverlayBpmColor,
        ),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '字重'),
        const SizedBox(height: AppSpacing.xs + 2),
        SegmentedButton<double>(
          segments: <ButtonSegment<double>>[
            for (final (weight, label) in const [
              (300.0, '细'),
              (400.0, '常规'),
              (600.0, '中粗'),
              (800.0, '粗'),
              (900.0, '特粗'),
            ])
              ButtonSegment(
                value: weight,
                label: Text(label, maxLines: 1, softWrap: false),
              ),
          ],
          selected: {_fontWeightSegment(style.bpmWeight)},
          showSelectedIcon: false,
          style: _segmentedStyle(context),
          onSelectionChanged: (selection) =>
              viewModel.setOverlayBpmWeight(selection.first),
        ),
        const SizedBox(height: AppSpacing.md),
        _fieldLabel(context, '字体'),
        const SizedBox(height: AppSpacing.xs + 2),
        FontFamilyField(
          fieldKey: const Key('overlay_font_field'),
          value: style.bpmFontFamily,
          fontFamilies: viewModel.fontFamilies,
          // 未单独指定时跟随「设置 → 全局字体」,而非系统默认。
          emptyLabel: '跟随全局(${viewModel.globalFontFamily ?? '系统默认'})',
          onChanged: viewModel.setOverlayBpmFontFamily,
        ),
        const SizedBox(height: AppSpacing.md),
        _toggleRow(
          '律动',
          '关闭后心率数字静止',
          style.bpmPulseEnabled,
          viewModel.setOverlayBpmPulseEnabled,
        ),
        const SizedBox(height: AppSpacing.xs),
        _toggleRow(
          'bpm 标签',
          '在数字旁显示 bpm 单位',
          style.showBpmLabel,
          viewModel.setOverlayShowBpmLabel,
        ),
      ],
    );
  }

  /// 「心电图」组:心形内心电波形的样式与线色。
  Widget _ecgGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '心电图',
      children: [
        _fieldLabel(context, '样式'),
        const SizedBox(height: AppSpacing.xs + 2),
        SegmentedButton<EcgStyle>(
          segments: _ecgStyleLabels.entries
              .map(
                (e) => ButtonSegment(
                  value: e.key,
                  label: Text(e.value, maxLines: 1, softWrap: false),
                ),
              )
              .toList(),
          selected: {style.ecgStyle},
          // 勾选图标会把五个分段的文字挤到换行,改用选中底色表达选中态。
          showSelectedIcon: false,
          style: _segmentedStyle(context),
          onSelectionChanged: (selection) {
            viewModel.setOverlayEcgStyle(selection.first);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _colorSwatchRow(
          context: context,
          id: 'ecg',
          label: '颜色',
          current: style.ecgColor,
          presets: _lineColorSwatches,
          onPicked: viewModel.setOverlayEcgColor,
        ),
      ],
    );
  }

  /// 「背景」组:背景板的尺寸、不透明度与配色。
  Widget _backgroundGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '背景',
      children: [
        ..._spaced([
          _StyleSlider(
            label: '宽度',
            value: style.backgroundWidth,
            min: 100,
            max: 240,
            divisions: 14,
            onChanged: viewModel.setOverlayBackgroundWidth,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            label: '高度',
            value: style.backgroundHeight,
            min: 120,
            max: 280,
            divisions: 16,
            onChanged: viewModel.setOverlayBackgroundHeight,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            label: '透明度',
            value: style.backgroundOpacity,
            min: 0,
            max: 1.0,
            divisions: 10,
            labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
            onChanged: viewModel.setOverlayBackgroundOpacity,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _colorSwatchRow(
          context: context,
          id: 'background',
          label: '颜色',
          current: style.backgroundColor,
          presets: _backgroundColorSwatches,
          onPicked: viewModel.setOverlayBackgroundColor,
        ),
      ],
    );
  }

  /// 「辉光」组:心形与数字外扩光晕的半径与强度。
  Widget _glowGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '辉光',
      children: [
        _toggleRow(
          '心跳辉光',
          '心形随心跳向外扩散的光晕',
          style.glowEnabled,
          viewModel.setOverlayGlowEnabled,
        ),
        const SizedBox(height: AppSpacing.sm),
        // 关闭辉光时半径/透明度不可调,避免出现「调了却没效果」的困惑。
        ..._spaced([
          _StyleSlider(
            id: 'glow_radius',
            label: '半径',
            value: style.glowRadius,
            min: 0,
            max: 3.0,
            divisions: 12,
            enabled: style.glowEnabled,
            labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
            onChanged: viewModel.setOverlayGlowRadius,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            id: 'glow_opacity',
            label: '透明度',
            value: style.glowOpacity,
            min: 0,
            max: 1.0,
            divisions: 10,
            enabled: style.glowEnabled,
            labelBuilder: (v) => v <= 0 ? '无' : '${(v * 100).round()}%',
            onChanged: viewModel.setOverlayGlowOpacity,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
        ]),
      ],
    );
  }

  /// 「图表」组:心率折线图的开关、采样时长、尺寸与配色。
  Widget _chartGroup(BuildContext context, OverlayStyle style) {
    return _group(
      context,
      title: '图表',
      children: [
        ..._spaced([
          _toggleRow(
            '显示折线图',
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
            label: '高度',
            value: style.chartHeight,
            min: 40,
            max: 160,
            divisions: 12,
            onChanged: viewModel.setOverlayChartHeight,
            onChangeEnd: (_) => viewModel.persistOverlayStyle(),
          ),
          _StyleSlider(
            label: '间距',
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
          id: 'chart',
          label: '颜色',
          current: style.chartLineColor,
          presets: _chartLineColorSwatches,
          onPicked: viewModel.setOverlayChartLineColor,
        ),
      ],
    );
  }

  /// 分段控件的统一样式:紧凑内边距、无勾选图标、选中段用主色底。
  static ButtonStyle _segmentedStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SegmentedButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHigh,
      foregroundColor: scheme.onSurface,
      selectedBackgroundColor: scheme.primary.withValues(alpha: 0.22),
      selectedForegroundColor: scheme.onSurface,
      side: BorderSide(color: scheme.outlineVariant),
      visualDensity: VisualDensity.compact,
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
  }

  /// 一组控件:组标题 + 组内条目,整组包在浅色卡片里形成层次。
  Widget _group(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              // 标题前的小色条:与页面级分区标题(全大写感字距)区分开,
              // 让人一眼看出这是「悬浮窗样式」下的子分组。
              Container(
                width: 3,
                height: 12,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppTheme.panelBorderColor(scheme)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
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

  /// 生成颜色色板行(固定单行)+ 末尾的自定义选色入口。
  ///
  /// 槽位按可用宽度等分、圆点直径随槽位缩放:无论手机窄屏、平板还是
  /// 桌面宽窗口,色板始终是同一行,不会因为折行让整组高度跳变。
  Widget _colorSwatchRow({
    required BuildContext context,
    required String id,
    required String label,
    required Color current,
    required List<Color> presets,
    required ValueChanged<Color> onPicked,
  }) {
    final isCustom = !presets.contains(current);
    final scheme = Theme.of(context).colorScheme;
    // 末尾的自定义入口也占一个槽位。
    final slotCount = presets.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / slotCount;
            // 留出槽位内边距,并限制上下限:过窄保证可点,过宽不至于散开。
            final diameter = (slot - AppSpacing.sm).clamp(18.0, 30.0);
            final iconSize = (diameter * 0.6).clamp(12.0, 16.0);
            return Row(
              // 单行色板行:测试按此 Key 校验所有圆点处于同一行。
              // Key 用与文案解耦的 id,改文案不影响测试。
              key: Key('swatch_row_$id'),
              children: [
                for (final color in presets)
                  Expanded(
                    child: _Swatch(
                      diameter: diameter,
                      color: color,
                      selected: current == color,
                      onTap: () => onPicked(color),
                    ),
                  ),
                // 自定义颜色:打开调色盘对话框;当前为自定义色时,
                // 外圈用该颜色本身标记(而不是主题主色),让自定义色
                // 在色板里仍然可辨识。
                Expanded(
                  child: _Swatch(
                    diameter: diameter,
                    selected: isCustom,
                    ringColor: isCustom ? current : null,
                    onTap: () async {
                      final picked = await _pickColor(context, current, label);
                      if (picked != null) onPicked(picked);
                    },
                    child: Icon(
                      Icons.add,
                      size: iconSize,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 打开自定义颜色选择器对话框;确定后返回所选颜色。
  Future<Color?> _pickColor(
    BuildContext context,
    Color initial,
    String title,
  ) => showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial, title: title),
  );
}

/// 带标签与实时数值的样式滑块。
///
/// 采用「标签 + 数值徽标 / 滑块」两行布局:数值始终右对齐单独成块,
/// 拖动时不会因数字宽度变化导致标签抖动。
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
    this.enabled = true,
    this.id,
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

  /// 是否可调节;false 时滑块禁用且文字变淡(如辉光关闭时的半径)。
  final bool enabled;

  /// 稳定标识;非 null 时生成 `style_slider_<id>` 的 Key,便于测试定位
  /// (文案会随产品调整,不宜用来定位控件)。
  final String? id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = labelBuilder?.call(value) ?? value.round().toString();
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? null : scheme.onSurface.withValues(alpha: 0.5),
    );
    return Column(
      key: id == null ? null : Key('style_slider_$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: labelStyle)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            // 去掉 M3 默认的刻度点,轨道更干净。
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            label: text,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
      ],
    );
  }
}

/// 颜色色板圆点:选中态用外圈描边表达。
///
/// 直径由所在槽位宽度推导,触控高度固定为 40,保证窄屏上也不会太难点。
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.selected,
    required this.onTap,
    required this.diameter,
    this.color,
    this.ringColor,
    this.child,
  });

  /// 色块颜色;为 null 时渲染 [child](自定义入口)。
  final Color? color;

  /// 选中态。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  /// 圆点直径(随可用宽度缩放)。
  final double diameter;

  /// 选中态外圈颜色;null 表示使用主题主色。
  final Color? ringColor;

  /// 自定义入口的内容。
  final Widget? child;

  /// 触控区域高度。
  static const double _touchHeight = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: _touchHeight / 2,
        containedInkWell: true,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: _touchHeight,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  width: selected ? 2.5 : 1,
                  color: selected
                      ? (ringColor ?? scheme.primary)
                      : scheme.onSurface.withValues(alpha: 0.18),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义颜色对话框:调色盘 + 十六进制输入,两者双向同步。
///
/// 输入框直接复用 [ColorPicker] 的 `hexInputController`:键入合法 hex
/// 会即时改变调色盘指针,拖动调色盘也会即时回写输入框,因此用户既可以
/// 目视取色,也可以粘贴设计稿上的色值。
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});

  /// 初始颜色。
  final Color initial;

  /// 字段名(用于标题与无障碍文案,如「心形颜色」)。
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color = widget.initial;

  /// 与调色盘双向同步的 hex 输入控制器。
  late final TextEditingController _hexController = TextEditingController(
    text: _toHex(widget.initial),
  );

  /// 转成 `#RRGGBB`(大写,忽略 alpha)。
  static String _toHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('自定义${widget.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ColorPicker 内部的格式下拉按钮需要 Material 祖先。
            Material(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ColorPicker(
                  pickerColor: _color,
                  // 调色盘取色 → 回写输入框由 hexInputController 负责,
                  // 这里只同步本地状态与预览色块。
                  onColorChanged: (color) {
                    if (color == _color) return;
                    setState(() => _color = color);
                  },
                  paletteType: PaletteType.hueWheel,
                  pickerAreaHeightPercent: 0.7,
                  displayThumbColor: true,
                  enableAlpha: false, // 透明度由独立滑块控制
                  // 禁用 rgb/hsv/hsl 标签行(其下拉按钮在桌面端触发
                  // LookupBoundary 查找异常)。
                  labelTypes: const [],
                  hexInputController: _hexController,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                // 当前颜色预览。
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: AppRadius.controlBorder,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    key: const Key('color_hex_input'),
                    controller: _hexController,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '十六进制',
                      hintText: '#RRGGBB',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
