import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/heart_rate_device.dart';
import '../../../core/theme/app_dimens.dart';
import '../view_models/home_view_model.dart';

/// 设备选择弹窗:扫描附近 BLE 设备并连接其中一个。
///
/// 默认只展示广播了标准心率服务(0x180D)的设备;部分手环不在广播包中
/// 声明服务,可打开「显示全部蓝牙设备」手动选择。
class DevicePickerDialog extends StatefulWidget {
  /// 创建设备选择弹窗。
  const DevicePickerDialog({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends State<DevicePickerDialog> {
  @override
  void initState() {
    super.initState();
    // 弹窗首帧完成后再开始扫描:beginDeviceScan 会通知 ViewModel,
    // 在 initState 的 build 阶段同步通知会触发「build 期间 setState」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.viewModel.beginDeviceScan());
      }
    });
  }

  @override
  void dispose() {
    // 弹窗关闭即停止扫描,避免蓝牙在后台持续耗电。
    unawaited(widget.viewModel.stopDeviceScan());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final devices = viewModel.discoveredDevices;
        final screenSize = MediaQuery.sizeOf(context);
        return AlertDialog(
          key: const Key('device_picker_dialog'),
          title: const Text('连接设备'),
          content: SizedBox(
            width: (screenSize.width - 96).clamp(280.0, 440.0),
            height: (screenSize.height - 260).clamp(240.0, 360.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请确保设备已开启心率广播(如小米手环:设置 → 心率广播)。',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SwitchListTile(
                  key: const Key('device_picker_show_all'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('显示全部蓝牙设备'),
                  value: viewModel.showAllDevices,
                  onChanged: viewModel.setShowAllDevices,
                ),
                if (viewModel.isScanning) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '正在搜索附近的心率设备…',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (viewModel.scanError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    viewModel.scanError!,
                    key: const Key('device_picker_error'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: devices.isEmpty
                      ? Center(
                          child: Text(
                            viewModel.isScanning
                                ? ''
                                : viewModel.scanError != null
                                ? ''
                                : '未发现设备,请确认设备已开启心率广播并靠近本机。',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          key: const Key('device_picker_list'),
                          itemCount: devices.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) => _DeviceTile(
                            device: devices[index],
                            onTap: () => _connect(devices[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: viewModel.isScanning
                  ? null
                  : () => unawaited(viewModel.rescanDevices()),
              child: const Text('重新扫描'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _connect(HeartRateDevice device) {
    unawaited(widget.viewModel.connectToDevice(device));
    Navigator.of(context).pop();
  }
}

/// 设备列表行:名称、信号强度与心率广播标记。
class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});

  final HeartRateDevice device;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rssi = device.rssi;
    final details = [
      if (device.isRemembered) '上次连接',
      if (rssi != null) '信号 $rssi dBm',
      if (device.advertisesHeartRate) '心率广播',
    ];
    return ListTile(
      key: ValueKey<String>('device_${device.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: Icon(
        device.advertisesHeartRate
            ? Icons.favorite_outline
            : device.isRemembered
            ? Icons.history
            : Icons.bluetooth_searching,
        color: device.advertisesHeartRate ? scheme.primary : scheme.outline,
      ),
      title: Text(
        device.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
