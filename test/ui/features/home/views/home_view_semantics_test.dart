import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_sight/data/repositories/heart_rate_repository.dart';
import 'package:pulse_sight/ui/core/theme/app_theme.dart';
import 'package:pulse_sight/ui/features/home/view_models/home_view_model.dart';
import 'package:pulse_sight/ui/features/home/views/home_view.dart';

import '../home_view_model_test.dart'
    show
        FakeDesktopOverlay,
        FakeMenubarDisplay,
        FakeObsOverlayDisplay,
        FakeScenarioHeartRateSource,
        FakeSettingsRepository;

/// 测试环境无 window_manager 原生插件,mock 基础查询通道。
void _mockWindowManagerChannel() {
  const channel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => false);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

/// 渲染 [HomeView] 并开启语义树,返回语义所有者与语义句柄。
///
/// 语义句柄需由调用方在断言后 `dispose`,否则测试框架会在结束时判定泄漏。
Future<(SemanticsOwner, SemanticsHandle)> _pumpWithSemantics(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _mockWindowManagerChannel();
  final handle = tester.ensureSemantics();

  final repository = HeartRateRepository(source: FakeScenarioHeartRateSource());
  final viewModel = HomeViewModel(
    repository: repository,
    settings: FakeSettingsRepository(),
    desktopOverlay: FakeDesktopOverlay(),
    menubar: FakeMenubarDisplay(),
    obsOverlay: FakeObsOverlayDisplay(),
  );
  await viewModel.init();
  addTearDown(() {
    viewModel.dispose();
    repository.dispose();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: HomeView(viewModel: viewModel),
    ),
  );
  await tester.pump();
  return (tester.binding.renderViews.first.owner!.semanticsOwner!, handle);
}

/// 语义所有者中挂载(attached)但无法从根节点遍历到的节点 id。
///
/// 这类「孤儿节点」会被序列化成没有父节点的引擎语义节点,引擎据此整体
/// 拒绝该帧更新并打印 `Failed to update ui::AXTree`(flutter/flutter#189902)。
Set<int> _orphanSemanticsNodeIds(SemanticsOwner owner) {
  final reachable = <int>{};
  void visit(SemanticsNode node) {
    reachable.add(node.id);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  final SemanticsNode? root = owner.rootSemanticsNode;
  if (root != null) {
    visit(root);
  }

  final orphans = <int>{};
  // 框架语义节点 id 取 16 位(见 SemanticsNode._maxFrameworkAccessibilityIdentifier)。
  for (var id = 0; id < 1 << 16; id++) {
    final node = owner.getSemanticsNode(id);
    if (node != null && !reachable.contains(id)) {
      orphans.add(id);
    }
  }
  return orphans;
}

void main() {
  group('HomeView 语义树完整性', () {
    testWidgets('桌面默认页不构建其它详情页且不产出孤儿语义节点', (tester) async {
      final (owner, handle) = await _pumpWithSemantics(
        tester,
        width: 1200,
        height: 800,
      );

      expect(find.byKey(const Key('desktop_pane_monitor')), findsOneWidget);
      // 非选中页必须完全不构建(含离屏):隐藏挂载的 Material Slider 会创建
      // OverlayPortal 值指示器语义节点,失去父节点后污染整棵语义树。
      expect(
        find.byKey(const Key('desktop_pane_display'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('desktop_pane_style'), skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(Slider, skipOffstage: false), findsNothing);
      expect(_orphanSemanticsNodeIds(owner), isEmpty);
      handle.dispose();
    });

    testWidgets('切换到样式页后只构建样式页且语义树仍然完整', (tester) async {
      final (owner, handle) = await _pumpWithSemantics(
        tester,
        width: 1200,
        height: 800,
      );

      await tester.tap(find.byKey(const Key('desktop_nav_style')));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('desktop_pane_style'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('desktop_pane_monitor'), skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(Slider, skipOffstage: false), findsWidgets);
      expect(_orphanSemanticsNodeIds(owner), isEmpty);
      handle.dispose();
    });

    testWidgets('窄布局下语义树完整', (tester) async {
      final (owner, handle) = await _pumpWithSemantics(
        tester,
        width: 400,
        height: 900,
      );

      expect(find.byKey(const Key('home_narrow_layout')), findsOneWidget);
      // 窄布局把样式控件与连接区放在同一个滚动视图里,滑块全部构建。
      expect(find.byType(Slider, skipOffstage: false), findsWidgets);
      expect(_orphanSemanticsNodeIds(owner), isEmpty);
      handle.dispose();
    });
  });
}
