import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/app_card.dart';
import '../../home/view_models/home_view_model.dart';
import 'sections/global_font_section.dart';

/// 设置页(窄布局 / 移动端入口):应用级偏好。
///
/// 桌面布局把同一设置区块放在左侧导航的「设置」详情页里
/// (见 `home_view.dart`),两处共用 [GlobalFontSection]。
class SettingsPage extends StatelessWidget {
  /// 创建设置页;[viewModel] 由上层注入。
  const SettingsPage({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('settings_page'),
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: homeNarrowMaxWidth),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: GlobalFontSection(viewModel: viewModel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
