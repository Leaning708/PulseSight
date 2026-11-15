import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_connection.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/bpm_display.dart';
import '../../../../core/widgets/heartbeat_heart.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../view_models/home_view_model.dart';

/// 连接状态的展示文案。
String connectionStatusLabel(HeartRateConnection connection) {
  return switch (connection) {
    HeartRateConnection.connected => '已连接(模拟)',
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

/// 窄布局连接区:红心、bpm、状态徽标与连接按钮。
class ConnectionSection extends StatelessWidget {
  /// 创建连接区;[viewModel] 由上层注入。
  const ConnectionSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = viewModel.connection == HeartRateConnection.connected;
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
          label: connectionStatusLabel(viewModel.connection),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: viewModel.canConnect
              ? () => viewModel.connect()
              : () => viewModel.disconnect(),
          icon: Icon(
            viewModel.canConnect
                ? Icons.monitor_heart_outlined
                : Icons.link_off,
          ),
          label: Text(viewModel.canConnect ? '连接手环(模拟)' : '断开连接'),
        ),
      ],
    );
  }
}
