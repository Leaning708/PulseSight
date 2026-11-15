import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/domain/models/overlay_style.dart';
import 'package:pulse_sight/ui/features/overlay/view_models/overlay_view_model.dart';

void main() {
  group('OverlayViewModel', () {
    late OverlayViewModel viewModel;

    setUp(() {
      viewModel = OverlayViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('update 连接中追加历史,超出上限移除最旧数据', () {
      for (var i = 0; i < 45; i++) {
        viewModel.update(bpm: 60 + i % 30, connected: true);
      }

      expect(viewModel.history.values.length, 40);
      expect(viewModel.history.values.last, 60 + 44 % 30);
    });

    test('断连时清空历史', () {
      viewModel.update(bpm: 72, connected: true);
      expect(viewModel.history.values, isNotEmpty);

      viewModel.update(bpm: null, connected: false);
      expect(viewModel.history.values, isEmpty);
    });

    test('setStyle 更新样式并在变化时通知', () {
      var notified = 0;
      viewModel.addListener(() => notified++);

      const style = OverlayStyle(heartSize: 80);
      viewModel.setStyle(style);
      expect(viewModel.style, style);
      expect(notified, 1);

      // 相同样式再次设置不重复通知。
      viewModel.setStyle(style);
      expect(notified, 1);
    });
  });
}
