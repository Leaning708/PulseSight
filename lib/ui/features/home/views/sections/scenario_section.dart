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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<HeartRateScenario>(
            segments: [
              for (final s in HeartRateScenario.values)
                ButtonSegment(value: s, label: Text(scenarioLabel(s))),
            ],
            selected: {scenario},
            onSelectionChanged: (selection) =>
                viewModel.setScenario(selection.first),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          scenarioDescription(scenario),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
