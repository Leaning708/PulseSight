import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/font_family_field.dart';
import '../../../home/view_models/home_view_model.dart';

/// 全局字体设置:应用界面统一字体,同时作为悬浮窗字体的默认值。
///
/// 字体族来自 [HomeViewModel.fontFamilies](桌面端经原生通道枚举系统字体);
/// 列表为空时只提供「系统默认」。
class GlobalFontSection extends StatelessWidget {
  /// 创建设置区块;[viewModel] 由上层注入。
  const GlobalFontSection({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  /// 桌面端样式页的字体下拉 id,便于测试定位。
  static const Key dropdownKey = Key('global_font_dropdown');

  /// 当前字体说明文本的 id,便于测试与无障碍定位。
  static const Key currentFontKey = Key('global_font_current');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final current = viewModel.globalFontFamily;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全局字体', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '应用界面统一使用该字体;悬浮窗未单独指定字体时同样跟随。',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '字体列表由系统提供,仅桌面端(Windows / macOS)可枚举。',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '当前:${current ?? '系统默认'}',
              key: currentFontKey,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FontFamilyField(
              fieldKey: dropdownKey,
              value: current,
              fontFamilies: viewModel.fontFamilies,
              emptyLabel: '系统默认',
              onChanged: viewModel.setGlobalFontFamily,
            ),
          ],
        );
      },
    );
  }
}
