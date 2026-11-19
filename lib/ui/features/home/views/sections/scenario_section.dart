import 'package:material_ui/material_ui.dart';

import '../../../../../domain/models/heart_rate_scenario.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../view_models/home_view_model.dart';

/// 模拟心率场景的短标签(低 / 中 / 高)。
String scenarioLabel(HeartRateScenario scenario) {
  return switch (scenario) {
    HeartRateScenario.low => '低',
    HeartRateScenario.medium => '中',
    HeartRateScenario.high => '高',
  };
}

/// 模拟心率场景的说明文案。
String scenarioDescription(HeartRateScenario scenario) {
  return switch (scenario) {
    HeartRateScenario.low =>
      '静息 / 睡眠,${scenario.minBpm}–${scenario.maxBpm} bpm',
    HeartRateScenario.medium =>
      '日常活动,${scenario.minBpm}–${scenario.maxBpm} bpm',
    HeartRateScenario.high => '运动状态,${scenario.minBpm}–${scenario.maxBpm} bpm',
  };
}

/// 模拟心率场景区内容:低 / 中 / 高三档切换 + 当前场景说明(不含标题)。
class ScenarioSection extends StatelessWidget {
  /// 创建场景区;[viewModel] 由上层注入。
  const ScenarioSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scenario = viewModel.scenario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<HeartRateScenario>(
          segments: [
            for (final s in HeartRateScenario.values)
              ButtonSegment(
                value: s,
                label: Text(scenarioLabel(s)),
                // 只显示选中态底色,不显示勾选图标(避免窄分段里文字换行)。
                icon: const SizedBox.shrink(),
              ),
          ],
          selected: {scenario},
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
            selectedBackgroundColor: scheme.primaryContainer,
            selectedForegroundColor: scheme.onPrimaryContainer,
            side: BorderSide.none,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.controlBorder,
            ),
          ),
          onSelectionChanged: (selection) =>
              viewModel.setScenario(selection.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          scenarioDescription(scenario),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
