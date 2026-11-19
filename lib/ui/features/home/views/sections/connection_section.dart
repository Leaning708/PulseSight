import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bpm_display.dart';
import '../../../../core/widgets/heartbeat_heart.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../view_models/home_view_model.dart';
import '../device_picker_dialog.dart';
import 'scenario_section.dart';

/// 连接状态的展示文案;[simulated] 为真时标注模拟数据源。
String connectionStatusLabel(
  HeartRateConnection connection, {
  bool simulated = false,
}) {
  return switch (connection) {
    HeartRateConnection.connected => simulated ? '已连接(模拟)' : '已连接',
    HeartRateConnection.connecting => '正在连接…',
    HeartRateConnection.disconnected => '未连接',
  };
}

/// 连接状态的展示色。
Color connectionStatusColor(
  HeartRateConnection connection,
  ColorScheme scheme,
) {
  return switch (connection) {
    HeartRateConnection.connected => const Color(0xFF3DDC84),
    HeartRateConnection.connecting => const Color(0xFFFFB74D),
    HeartRateConnection.disconnected => scheme.outline,
  };
}

/// 连接按钮文案:连接中允许取消,已连接可断开;模拟模式使用独立文案。
String connectionButtonLabel(
  HeartRateConnection connection, {
  bool simulated = false,
}) {
  return switch (connection) {
    HeartRateConnection.disconnected => simulated ? '开始模拟' : '连接设备',
    HeartRateConnection.connecting => '取消连接',
    HeartRateConnection.connected => simulated ? '停止模拟' : '断开连接',
  };
}

/// 连接区:红心、bpm、状态胶囊与主操作按钮。
///
/// [onStage] 为真表示渲染在深色舞台上(主界面监视区),
/// 文字与胶囊按深色底衬托;否则按当前主题渲染(桌面详情面板等)。
class ConnectionSection extends StatelessWidget {
  /// 创建连接区;[viewModel] 由上层注入。
  const ConnectionSection({
    super.key,
    required this.viewModel,
    this.onStage = false,
  });

  final HomeViewModel viewModel;

  /// 是否渲染在深色舞台上。
  final bool onStage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
    final simulated = viewModel.isSimulatedMode;
    final device = viewModel.connectedDevice;
    final error = viewModel.connectionError;
    final muted = onStage ? const Color(0xFF9B9CA3) : scheme.onSurfaceVariant;
    return Column(
      children: [
        HeartbeatHeart(
          size: onStage ? 200 : 180,
          bpm: connected ? viewModel.bpm : null,
        ),
        const SizedBox(height: AppSpacing.md),
        BpmDisplay(
          bpm: connected ? viewModel.bpm : null,
          spacing: 6,
          numberStyle: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            color: connected
                ? (onStage ? const Color(0xFFFFFFFF) : scheme.onSurface)
                : muted.withValues(alpha: 0.5),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: muted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 舞台是深色底:胶囊单独套深色方案,避免浅色主题下胶囊几乎不可见。
        _stageThemed(
          context,
          child: StatusPill(
            color: connectionStatusColor(viewModel.connection, scheme),
            label: connectionStatusLabel(
              viewModel.connection,
              simulated: simulated,
            ),
          ),
        ),
        if (device != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '设备:${device.displayName}',
            key: const Key('connection_device_name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 16, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  error,
                  key: const Key('connection_error'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: onStage ? double.infinity : null,
          child: FilledButton.icon(
            key: const Key('connection_primary_button'),
            onPressed: switch (viewModel.connection) {
              HeartRateConnection.disconnected => () => _handleConnect(context),
              // 模拟模式的停止 / 取消同时退出模拟,回到真实设备模式。
              HeartRateConnection.connecting || HeartRateConnection.connected =>
                simulated
                    ? () => viewModel.stopSimulation()
                    : viewModel.disconnect,
            },
            icon: Icon(
              viewModel.connection == HeartRateConnection.disconnected
                  ? simulated
                        ? Icons.play_arrow_rounded
                        : Icons.bluetooth_searching
                  : Icons.stop_circle_outlined,
              size: 20,
            ),
            label: Text(
              connectionButtonLabel(viewModel.connection, simulated: simulated),
            ),
          ),
        ),
        if (viewModel.supportsScenario) ...[
          const SizedBox(height: AppSpacing.xl),
          _stageThemed(context, child: ScenarioSection(viewModel: viewModel)),
        ],
      ],
    );
  }

  /// 深色舞台上渲染 [child] 时套一份深色配色;非舞台场景原样返回。
  ///
  /// 只包裹确实需要深色配色的控件,不覆盖整段子树——`showDialog` 会继承
  /// 调用方的 Theme,整段覆盖会让弹窗拿到深色方案的浅色文字。
  Widget _stageThemed(BuildContext context, {required Widget child}) {
    if (!onStage) return child;
    return Theme(
      data: Theme.of(context)
          .copyWith(colorScheme: AppTheme.schemeFor(Brightness.dark)),
      child: child,
    );
  }

  /// 模拟模式直接开始模拟;真实模式有设备选择能力时弹窗扫描。
  Future<void> _handleConnect(BuildContext context) async {
    if (viewModel.isSimulatedMode || !viewModel.supportsDevicePicker) {
      await viewModel.connect();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => DevicePickerDialog(viewModel: viewModel),
    );
  }
}
