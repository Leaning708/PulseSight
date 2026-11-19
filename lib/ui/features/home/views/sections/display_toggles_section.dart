import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/setting_row.dart';
import '../../view_models/home_view_model.dart';

/// 显示端开关区内容:按平台能力渲染对应开关行(不含标题)。
class DisplayTogglesSection extends StatelessWidget {
  /// 创建显示端开关区;[viewModel] 由上层注入。
  const DisplayTogglesSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (viewModel.supportsDesktopOverlay) ...[
        SettingRow(
          icon: Icons.open_with,
          title: '桌面悬浮窗',
          subtitle: const Text('在桌面悬浮显示实时心率,关闭穿透后可拖动'),
          trailing: Switch(
            value: viewModel.desktopOverlayEnabled,
            onChanged: (value) => viewModel.setDesktopOverlayEnabled(value),
          ),
        ),
        SettingRow(
          enabled: viewModel.desktopOverlayEnabled,
          icon: Icons.mouse,
          title: '鼠标穿透',
          subtitle: const Text('开启后点击会穿透悬浮窗作用于下层内容'),
          trailing: Switch(
            value: viewModel.mousePassthroughEnabled,
            onChanged: viewModel.desktopOverlayEnabled
                ? (value) => viewModel.setMousePassthroughEnabled(value)
                : null,
          ),
        ),
      ],
      if (viewModel.supportsMenubar)
        SettingRow(
          icon: Icons.favorite_border,
          title: '菜单栏心率',
          subtitle: const Text('在系统菜单栏实时显示当前心率'),
          trailing: Switch(
            value: viewModel.menubarEnabled,
            onChanged: (value) => viewModel.setMenubarEnabled(value),
          ),
        ),
      if (viewModel.supportsAndroidDisplay) ...[
        SettingRow(
          icon: Icons.picture_in_picture_alt,
          title: '悬浮窗',
          onTap: () =>
              _setAndroidOverlay(context, !viewModel.androidOverlayEnabled),
          subtitle: const Text('在其他应用上层悬浮显示实时心率,可拖动'),
          trailing: Switch(
            value: viewModel.androidOverlayEnabled,
            onChanged: (value) => _setAndroidOverlay(context, value),
          ),
        ),
        // 手机端的「穿透」是手指触摸而非鼠标,故与桌面端的「鼠标穿透」分开命名。
        SettingRow(
          enabled: viewModel.androidOverlayEnabled,
          icon: Icons.touch_app_outlined,
          title: '触摸穿透',
          onTap: viewModel.androidOverlayEnabled
              ? () => viewModel.setAndroidTouchPassthroughEnabled(
                  !viewModel.androidTouchPassthroughEnabled,
                )
              : null,
          subtitle: const Text('开启后触摸会穿透悬浮窗作用于下层内容'),
          trailing: Switch(
            value: viewModel.androidTouchPassthroughEnabled,
            onChanged: viewModel.androidOverlayEnabled
                ? viewModel.setAndroidTouchPassthroughEnabled
                : null,
          ),
        ),
        SettingRow(
          enabled: viewModel.androidOverlayEnabled,
          icon: Icons.vertical_align_center,
          title: '边缘吸附',
          onTap: viewModel.androidOverlayEnabled
              ? () => viewModel.setAndroidEdgeSnapEnabled(
                  !viewModel.androidEdgeSnapEnabled,
                )
              : null,
          subtitle: const Text('拖动松手后自动吸附到最近的左右边缘'),
          trailing: Switch(
            value: viewModel.androidEdgeSnapEnabled,
            onChanged: viewModel.androidOverlayEnabled
                ? viewModel.setAndroidEdgeSnapEnabled
                : null,
          ),
        ),
        SettingRow(
          icon: Icons.notifications_active_outlined,
          title: '状态栏',
          onTap: () => _setStatusBar(context, !viewModel.statusBarEnabled),
          subtitle: const Text('通过持续通知展示当前心率'),
          trailing: Switch(
            value: viewModel.statusBarEnabled,
            onChanged: (value) => _setStatusBar(context, value),
          ),
        ),
      ],
      if (viewModel.supportsObsOverlay)
        SettingRow(
          icon: Icons.podcasts,
          title: 'OBS 浏览器源',
          onTap: () => _setObs(context, !viewModel.obsOverlayEnabled),
          subtitle: viewModel.obsOverlayEnabled
              ? _ObsUrlRow(url: viewModel.obsOverlayUrl)
              : const Text('在 OBS 中添加浏览器源即可录制显示,桌面不显示窗口'),
          trailing: Switch(
            value: viewModel.obsOverlayEnabled,
            onChanged: (value) => _setObs(context, value),
          ),
        ),
    ];
    // 条目之间插入细线分隔;卡片左右内边距由这里补齐,
    // 使分隔线与卡片边缘保持内缩对齐。
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const CardDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// 开关 Android 悬浮窗;权限未授予时提示。
  Future<void> _setAndroidOverlay(BuildContext context, bool value) async {
    final ok = await viewModel.setAndroidOverlayEnabled(value);
    if (!ok && context.mounted) {
      _showSnackBar(context, '未授予悬浮窗权限,请在系统设置中开启');
    }
  }

  /// 开关状态栏心率通知;通知权限未授予时提示。
  Future<void> _setStatusBar(BuildContext context, bool value) async {
    final ok = await viewModel.setStatusBarEnabled(value);
    if (!ok && context.mounted) {
      _showSnackBar(context, '未授予通知权限,无法在状态栏展示');
    }
  }

  /// 开关 OBS 浏览器源;本地服务启动失败时提示。
  Future<void> _setObs(BuildContext context, bool value) async {
    final ok = await viewModel.setObsOverlayEnabled(value);
    if (!ok && context.mounted) {
      _showSnackBar(context, '本地服务启动失败,端口可能被占用');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// OBS 浏览器源地址行:URL + 复制按钮。
class _ObsUrlRow extends StatelessWidget {
  const _ObsUrlRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            url,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // Semantics 边界规避 Flutter Windows 的 AXTree 序列化错误
        // (flutter/flutter#182444)。
        Semantics(
          container: true,
          child: Tooltip(
            message: '复制浏览器源地址',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('已复制浏览器源地址:$url')));
                }
              },
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.copy, size: 16, color: scheme.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
