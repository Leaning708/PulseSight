import 'package:material_ui/material_ui.dart';

import '../theme/app_dimens.dart';
import '../theme/app_theme.dart';

/// 系统字体选择入口:显示当前字体 + 点击弹出带搜索的字体列表。
///
/// 替代原生 `DropdownButton`:macOS / Windows 的字体族动辄数百个,
/// 长下拉菜单既难找也难看,这里改成「输入框样式的触发器 + 可搜索弹层」。
/// 弹层内每行按该字体自身渲染预览,方便一眼看到效果。
class FontFamilyField extends StatelessWidget {
  /// 创建字体选择入口。
  const FontFamilyField({
    super.key,
    required this.value,
    required this.fontFamilies,
    required this.onChanged,
    required this.emptyLabel,
    this.fieldKey,
  });

  /// 当前选中字体族;null 表示「跟随全局 / 系统默认」。
  final String? value;

  /// 可选字体族列表(已排序)。
  final List<String> fontFamilies;

  /// 选择回调;选「默认」时传 null。
  final ValueChanged<String?> onChanged;

  /// 未指定字体时的展示文案(如「跟随全局(系统默认)」)。
  final String emptyLabel;

  /// 触发器 Key,便于测试定位。
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: fieldKey,
      borderRadius: AppRadius.controlBorder,
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: AppTheme.panelBorderColor(scheme)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? emptyLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.unfold_more, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (_) => FontFamilyPickerDialog(
        value: value,
        fontFamilies: fontFamilies,
        emptyLabel: emptyLabel,
      ),
    );
    // 取消时 showDialog 返回 null,与「选择默认」的 null 无法区分,
    // 因此弹层用哨兵值表示取消。
    if (picked == FontFamilyPickerDialog.kCancel) return;
    onChanged(picked);
  }
}

/// 可搜索的字体列表弹层。
class FontFamilyPickerDialog extends StatelessWidget {
  /// 创建弹层。
  const FontFamilyPickerDialog({
    super.key,
    required this.value,
    required this.fontFamilies,
    required this.emptyLabel,
  });

  /// 当前字体族;null 表示默认。
  final String? value;

  /// 可选字体族。
  final List<String> fontFamilies;

  /// 默认项文案。
  final String emptyLabel;

  /// 取消哨兵值。
  static const String kCancel = '\u0000cancel';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 宽窗口下不至于拉成长条,窄窗口下留出边距。
          maxWidth: 420,
          maxHeight: (size.height - 80).clamp(320.0, 560.0),
        ),
        child: _FontFamilyPickerBody(
          value: value,
          fontFamilies: fontFamilies,
          emptyLabel: emptyLabel,
        ),
      ),
    );
  }
}

class _FontFamilyPickerBody extends StatefulWidget {
  const _FontFamilyPickerBody({
    required this.value,
    required this.fontFamilies,
    required this.emptyLabel,
  });

  final String? value;
  final List<String> fontFamilies;
  final String emptyLabel;

  @override
  State<_FontFamilyPickerBody> createState() => _FontFamilyPickerBodyState();
}

class _FontFamilyPickerBodyState extends State<_FontFamilyPickerBody> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  /// 按查询过滤后的字体族;空查询返回全部。
  List<String> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.fontFamilies;
    return widget.fontFamilies
        .where((family) => family.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final query = _search.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部:标题 + 搜索框。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择字体', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('font_picker_search'),
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索字体',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _search.clear,
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.controlBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([_search]),
            builder: (context, _) {
              final filtered = _filtered;
              final query = _search.text.trim();
              // 搜索时仅当查询命中默认项文案才保留该行。
              final showDefault =
                  query.isEmpty ||
                  widget.emptyLabel.toLowerCase().contains(query.toLowerCase());
              if (filtered.isEmpty && !showDefault) {
                return Center(
                  child: Text(
                    '没有匹配的字体',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ListView.builder(
                key: const Key('font_picker_list'),
                // 不用固定 itemExtent:部分字体行高明显偏高,固定高度会裁字。
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                itemCount: filtered.length + (showDefault ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showDefault && index == 0) {
                    return _FontRow(
                      label: widget.emptyLabel,
                      selected: widget.value == null,
                      onTap: () => Navigator.pop(context, null),
                    );
                  }
                  final family = filtered[showDefault ? index - 1 : index];
                  return _FontRow(
                    key: Key('font_option_$family'),
                    label: family,
                    fontFamily: family,
                    selected: family == widget.value,
                    onTap: () => Navigator.pop(context, family),
                  );
                },
              );
            },
          ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        // 底部:数量提示 + 取消。
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                // 底栏跟随搜索同步:过滤时显示匹配数量,避免与列表不符。
                child: ListenableBuilder(
                  listenable: _search,
                  builder: (context, _) {
                    final query = _search.text.trim();
                    final count = _filtered.length;
                    return Text(
                      query.isEmpty
                          ? '${widget.fontFamilies.length} 个字体'
                          : '匹配 $count 个',
                      key: const Key('font_picker_count'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, FontFamilyPickerDialog.kCancel),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 字体列表行:左侧按该字体渲染预览,选中态高亮。
class _FontRow extends StatelessWidget {
  const _FontRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
  });

  final String label;

  /// 预览用字体族;null 表示默认项。
  final String? fontFamily;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: fontFamily,
                  // 中文字形由主题回退链补齐:很多拉丁字体不含汉字。
                  fontFamilyFallback: AppTheme.cjkFontFamilyFallback,
                  fontWeight: selected ? FontWeight.w600 : null,
                  color: selected ? scheme.primary : null,
                ),
              ),
            ),
            if (fontFamily != null) ...[
              const SizedBox(width: AppSpacing.sm),
              // 固定样张:一眼看出该字体的字母与数字形态。
              Text(
                'Aa 123',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: fontFamily,
                  fontFamilyFallback: AppTheme.cjkFontFamilyFallback,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.8)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.check, size: 18, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}
