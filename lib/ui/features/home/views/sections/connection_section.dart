import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/bpm_display.dart';
import '../../../../core/widgets/heartbeat_heart.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../view_models/home_view_model.dart';
import '../device_picker_dialog.dart';

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
    HeartRateConnection.connected => Colors.green.shade600,
    HeartRateConnection.connecting => Colors.orange.shade600,
    HeartRateConnection.disconnected => scheme.outline,
  };
}

/// 连接按钮文案:连接中允许取消,已连接可断开。
String connectionButtonLabel(HeartRateConnection connection) {
  return switch (connection) {
    HeartRateConnection.disconnected => '连接设备',
    HeartRateConnection.connecting => '取消连接',
    HeartRateConnection.connected => '断开连接',
  };
}

/// 窄布局连接区:红心、bpm、状态徽标与连接按钮。
class ConnectionSection extends StatelessWidget {
  /// 创建连接区;[viewModel] 由上层注入。
  const ConnectionSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
    final device = viewModel.connectedDevice;
    final error = viewModel.connectionError;
    return Column(
      children: [
        HeartbeatHeart(size: 180, bpm: connected ? viewModel.bpm : null),
        const SizedBox(height: AppSpacing.lg),
        BpmDisplay(
          bpm: connected ? viewModel.bpm : null,
          numberStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StatusPill(
          color: connectionStatusColor(viewModel.connection, scheme),
          label: connectionStatusLabel(
            viewModel.connection,
            simulated: viewModel.supportsScenario,
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
                ?.copyWith(color: scheme.onSurfaceVariant),
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
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: viewModel.connection == HeartRateConnection.disconnected
              ? () => _handleConnect(context)
              : () => viewModel.disconnect(),
          icon: Icon(
            viewModel.connection == HeartRateConnection.disconnected
                ? Icons.bluetooth_searching
                : Icons.link_off,
          ),
          label: Text(connectionButtonLabel(viewModel.connection)),
        ),
      ],
    );
  }

  /// 有设备选择能力时弹窗扫描,否则直接交给数据源连接。
  Future<void> _handleConnect(BuildContext context) async {
    if (!viewModel.supportsDevicePicker) {
      await viewModel.connect();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => DevicePickerDialog(viewModel: viewModel),
    );
  }
}
