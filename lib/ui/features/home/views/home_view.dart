import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/status_pill.dart';
import '../view_models/home_view_model.dart';
import 'sections/connection_section.dart';
import 'sections/display_toggles_section.dart';
import 'sections/overlay_style_pane.dart';
import 'sections/overlay_style_section.dart';

/// 主界面:连接管理 + 各显示端开关。
///
/// 按窗口宽度自适应([desktopBreakpoint]):宽窗口为设置式布局
/// (左侧导航栏 + 右侧详情面板),窄窗口保持手机形态的单列布局。
class HomeView extends StatelessWidget {
  /// 创建主界面;[viewModel] 由 DI 注入。
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= desktopBreakpoint) {
            return _DesktopHomeBody(viewModel: viewModel);
          }
          return _NarrowHomeBody(viewModel: viewModel);
        },
      ),
    );
  }
}

/// 窄布局主体:手机形态的单列设置页(与旧版结构保持一致)。
class _NarrowHomeBody extends StatelessWidget {
  const _NarrowHomeBody({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_narrow_layout'),
      appBar: AppBar(
        title: const Text('PulseSight'),
        actions: [
          _ThemeModeButton(viewModel: viewModel),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: homeNarrowMaxWidth),
            child: ListenableBuilder(
              listenable: viewModel,
              // 设置页子项数量固定,用 Column 而非 ListView:Flutter Windows 的
              // 可访问性桥在「ListView + Tooltip」组合下会刷
              // 「Failed to update ui::AXTree」错误(flutter/flutter#182444)。
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    ConnectionSection(viewModel: viewModel),
                    const SizedBox(height: AppSpacing.xxl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    DisplayTogglesSection(viewModel: viewModel),
                    if (viewModel.supportsDesktopOverlay ||
                        viewModel.supportsAndroidDisplay) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '悬浮窗样式',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '更改实时生效并自动保存(需打开上方悬浮窗开关查看)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OverlayStyleSection(viewModel: viewModel),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    _footnote(context),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 页脚说明文字。
Widget _footnote(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Text(
    '支持小米手环等标准 BLE 心率广播设备;连接前请在设备上开启「心率广播」并靠近本机。',
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant),
  );
}

/// 详情面板页头:标题 + 副标题。
Widget _paneHeader(BuildContext context, String title, String subtitle) {
  final scheme = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ],
  );
}

/// 详情面板内容区的统一内边距。
const EdgeInsets _panePadding = EdgeInsets.fromLTRB(
  AppSpacing.xxl,
  AppSpacing.xl,
  AppSpacing.xxl,
  AppSpacing.xxl,
);

/// 桌面设置式布局主体:顶栏 + 左侧导航栏 + 右侧详情面板(IndexedStack)。
class _DesktopHomeBody extends StatefulWidget {
  const _DesktopHomeBody({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<_DesktopHomeBody> createState() => _DesktopHomeBodyState();
}

class _DesktopHomeBodyState extends State<_DesktopHomeBody> {
  /// 当前选中的导航索引;默认停留在「监视器」页。
  int _selectedIndex = 0;

  /// 当前平台可用的导航条目,顺序与详情面板的 IndexedStack 子项一致。
  List<_DesktopNavEntry> _entries() {
    final vm = widget.viewModel;
    final showDisplayPanel =
        vm.supportsDesktopOverlay ||
        vm.supportsMenubar ||
        vm.supportsAndroidDisplay ||
        vm.supportsObsOverlay;
    return [
      _DesktopNavEntry(
        keyName: 'monitor',
        icon: Icons.monitor_heart_outlined,
        label: '监视器',
        pane: _MonitorPane(viewModel: vm),
      ),
      if (showDisplayPanel)
        _DesktopNavEntry(
          keyName: 'display',
          icon: Icons.devices_outlined,
          label: '显示端',
          pane: _DisplayPane(viewModel: vm),
        ),
      if (vm.supportsDesktopOverlay || vm.supportsAndroidDisplay)
        _DesktopNavEntry(
          keyName: 'style',
          icon: Icons.tune_outlined,
          label: '悬浮窗样式',
          pane: _StylePane(viewModel: vm),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (_selectedIndex >= entries.length) {
      _selectedIndex = 0;
    }
    return Scaffold(
      key: const Key('home_desktop_layout'),
      body: Column(
        children: [
          _DesktopHeader(viewModel: widget.viewModel),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavRail(
                  entries: entries,
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      for (final entry in entries)
                        KeyedSubtree(
                          key: Key('desktop_pane_${entry.keyName}'),
                          child: entry.pane,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 桌面导航条目:图标 + 标签 + 对应详情面板。
class _DesktopNavEntry {
  const _DesktopNavEntry({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.pane,
  });

  /// 生成测试用 Key 使用的英文标识。
  final String keyName;

  final IconData icon;

  final String label;

  final Widget pane;
}

/// 桌面左侧导航栏:设置应用式的分类切换。
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DesktopNavEntry> entries;

  final int selectedIndex;

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('desktop_nav_rail'),
      width: desktopNavRailWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++)
              _NavRailItem(
                entry: entries[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            const Spacer(),
            _footnote(context),
          ],
        ),
      ),
    );
  }
}

/// 导航栏条目:选中态用 secondaryContainer 底色 + 加粗标签。
class _NavRailItem extends StatelessWidget {
  const _NavRailItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _DesktopNavEntry entry;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: AppRadius.controlBorder,
        child: InkWell(
          key: Key('desktop_nav_${entry.keyName}'),
          borderRadius: AppRadius.controlBorder,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(entry.icon, size: 20, color: foreground),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    entry.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「监视器」详情页:居中连接区(红心 + bpm + 状态胶囊 + 连接按钮)。
class _MonitorPane extends StatelessWidget {
  const _MonitorPane({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ConnectionSection(viewModel: viewModel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DisplayPane extends StatelessWidget {
  const _DisplayPane({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: _panePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: desktopPaneMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _paneHeader(context, '显示端', '选择心率在哪些位置显示'),
              const SizedBox(height: AppSpacing.lg),
              DisplayTogglesSection(viewModel: viewModel),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「悬浮窗样式」详情页:页头 + 预览/分组控件区(高度受限,内部滚动)。
class _StylePane extends StatelessWidget {
  const _StylePane({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _panePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _paneHeader(context, '悬浮窗样式', '更改实时生效并自动保存(需打开显示端开关查看)'),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: OverlayStylePane(viewModel: viewModel)),
        ],
      ),
    );
  }
}

/// 桌面顶部栏:隐藏原生标题栏后承担窗口拖拽、双击最大化 / 还原。
///
/// - macOS:系统在顶部约 28px 的透明标题栏区保留红绿灯,该区域由
///   系统处理拖拽且 Flutter 控件收不到点击,内容行整体下移至其下方,
///   因此横向无需再避让,应用名称可靠左显示;
/// - Windows:无系统标题栏,右上角自绘最小化 / 最大化 / 关闭按钮,
///   内容行为其预留右侧宽度。
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.viewModel});

  final HomeViewModel viewModel;

  /// macOS 透明标题栏(红绿灯)占用的顶部高度,该区域内不可交互。
  static const double _macosTitleBarInset = 28;

  /// 顶部栏内容行高度(以行内最高控件为准)。
  static const double _contentHeight = 40;

  /// Windows 自绘窗口按钮(含留白)占据的右侧宽度。
  static const double _windowsCaptionReserve = 146;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
    final isMacos = Platform.isMacOS;
    final contentRow = Row(
      children: [
        Icon(Icons.favorite, size: 22, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'PulseSight',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        // 状态胶囊不参与指针事件,使空白处拖拽可从其上发起。
        IgnorePointer(
          child: StatusPill(
            color: connectionStatusColor(viewModel.connection, scheme),
            label: connectionStatusLabel(
              viewModel.connection,
              simulated: viewModel.isSimulatedMode,
            ),
            detail: connected ? '${viewModel.bpm ?? '--'} bpm' : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ThemeModeButton(viewModel: viewModel),
        if (Platform.isWindows) const SizedBox(width: _windowsCaptionReserve),
      ],
    );
    return SizedBox(
      height: isMacos ? _macosTitleBarInset + _contentHeight : _contentHeight,
      child: Stack(
        children: [
          // 底层:整条顶部栏作为窗口拖拽区(含双击最大化 / 还原)。
          // 垫底而非包裹按钮,避免双击识别器拖慢上层按钮的单击响应。
          Positioned.fill(
            child: DragToMoveArea(child: const SizedBox.expand()),
          ),
          // 内容行:macOS 下移至系统红绿灯区之下,应用名称可靠左显示。
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              isMacos ? _macosTitleBarInset : AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: contentRow,
          ),
          if (Platform.isWindows)
            const Align(
              alignment: Alignment.topRight,
              child: _WindowsCaptionButtons(),
            ),
        ],
      ),
    );
  }
}

/// Windows 自绘窗口控制按钮:最小化 / 最大化(还原)/ 关闭。
///
/// 贴右上角排布,最大化状态经 [WindowListener] 与窗口事件保持同步。
class _WindowsCaptionButtons extends StatefulWidget {
  const _WindowsCaptionButtons();

  @override
  State<_WindowsCaptionButtons> createState() => _WindowsCaptionButtonsState();
}

class _WindowsCaptionButtonsState extends State<_WindowsCaptionButtons>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted && value != _maximized) {
        setState(() => _maximized = value);
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // 必须收缩为内容宽度(mainAxisSize.min):Row 默认占满可用宽度,
    // 三个按钮会被排到行的最左侧,叠在标题上而非右上角。
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindowCaptionButton.minimize(
          brightness: brightness,
          onPressed: windowManager.minimize,
        ),
        _maximized
            ? WindowCaptionButton.unmaximize(
                brightness: brightness,
                onPressed: windowManager.unmaximize,
              )
            : WindowCaptionButton.maximize(
                brightness: brightness,
                onPressed: windowManager.maximize,
              ),
        WindowCaptionButton.close(
          brightness: brightness,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

/// 主题模式切换按钮:跟随系统 → 浅色 → 深色循环。
class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final mode = viewModel.themeMode;
    // Semantics 边界用于规避 Flutter Windows 的 AXTree 序列化错误
    // (flutter/flutter#182444):Tooltip 的 overlay 节点需要独立语义边界。
    return Semantics(
      container: true,
      child: IconButton(
        key: const Key('theme_mode_button'),
        visualDensity: VisualDensity.compact,
        tooltip: switch (mode) {
          ThemeMode.system => '主题:跟随系统',
          ThemeMode.light => '主题:浅色',
          ThemeMode.dark => '主题:深色',
        },
        icon: Icon(switch (mode) {
          ThemeMode.system => Icons.brightness_auto_outlined,
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
        }),
        onPressed: () {
          final next = switch (viewModel.themeMode) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => ThemeMode.system,
          };
          viewModel.setThemeMode(next);
        },
      ),
    );
  }
}
