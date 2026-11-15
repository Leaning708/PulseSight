import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../view_models/home_view_model.dart';
import 'overlay_style_section.dart';

/// 桌面「悬浮窗样式」详情页内容:左侧实时预览固定不随滚动,
/// 右侧分组控件独立滚动,调节时预览始终可见。
///
/// 可用宽度低于 [overlayStyleSideBySideMinWidth] 时(窗口接近断点)
/// 退化为预览在上、控件在下的整体滚动布局。
class OverlayStylePane extends StatelessWidget {
  /// 创建样式页内容;[viewModel] 由上层注入。
  const OverlayStylePane({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  /// 桌面样式页的预览舞台宽度。
  static const double _previewWidth = 260;

  /// 桌面样式页的预览舞台高度。
  static const double _previewHeight = 330;

  /// 滚动内容的内边距:右侧留出悬浮滚动条的宽度,避免遮盖滑块数值。
  static const EdgeInsets _scrollPadding = EdgeInsets.only(
    right: AppSpacing.lg,
    bottom: AppSpacing.lg,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final preview = OverlayStylePreview(
          viewModel: viewModel,
          width: _previewWidth,
          height: _previewHeight,
          caption: '实时预览 · 与悬浮窗观感一致',
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide =
                constraints.maxWidth >= overlayStyleSideBySideMinWidth;
            if (!sideBySide) {
              return SingleChildScrollView(
                padding: _scrollPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: preview),
                    const SizedBox(height: AppSpacing.lg),
                    OverlayStyleControls(viewModel: viewModel),
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 预览列固定:不参与右侧控件滚动。
                SizedBox(
                  width: _previewWidth,
                  child: SingleChildScrollView(child: preview),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: SingleChildScrollView(
                    // 右侧留出悬浮滚动条的宽度,避免遮盖滑块数值。
                    padding: _scrollPadding,
                    child: OverlayStyleControls(viewModel: viewModel),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
