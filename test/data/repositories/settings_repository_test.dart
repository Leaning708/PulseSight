import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_sight/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  /// 用内存实现替换平台层,并预置 [data] 作为「历史版本已存下的设置」。
  void useInMemoryPrefs([Map<String, Object> data = const {}]) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(Map.of(data));
  }

  group('SharedPreferencesSettingsRepository 旧键迁移', () {
    test('旧键名被搬到新键名并可被 loadAll 读到', () async {
      useInMemoryPrefs({
        // 命名梳理前的键名。
        'overlay.gap': 18.0,
        'overlay.opacity': 0.6,
        'overlay.text_color': 'ff00ff00',
        'overlay.text_weight': 900.0,
        'overlay.text_font_family': '微软雅黑',
        'overlay.text_pulse_enabled': false,
      });
      final repository = SharedPreferencesSettingsRepository();

      final values = await repository.loadAll();

      expect(values[SettingsKeys.overlayHeartTextGap], 18.0);
      expect(values[SettingsKeys.overlayContentOpacity], 0.6);
      expect(values[SettingsKeys.overlayBpmColor], 'ff00ff00');
      expect(values[SettingsKeys.overlayBpmWeight], 900.0);
      expect(values[SettingsKeys.overlayBpmFontFamily], '微软雅黑');
      expect(values[SettingsKeys.overlayBpmPulseEnabled], isFalse);

      // 迁移后旧键应被清除,避免下次再搬一遍。
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getString('overlay.text_color'), isNull);
      expect(await prefs.getDouble('overlay.gap'), isNull);
      // 新键已落盘。
      expect(await prefs.getDouble(SettingsKeys.overlayHeartTextGap), 18.0);
    });

    test('新键已有值时不被旧键覆盖', () async {
      useInMemoryPrefs({
        SettingsKeys.overlayBpmWeight: 300.0,
        'overlay.text_weight': 900.0,
      });
      final repository = SharedPreferencesSettingsRepository();

      final values = await repository.loadAll();

      expect(values[SettingsKeys.overlayBpmWeight], 300.0);
    });

    test('没有旧键时保持默认(空值)且不报错', () async {
      useInMemoryPrefs();
      final repository = SharedPreferencesSettingsRepository();

      final values = await repository.loadAll();

      expect(values[SettingsKeys.overlayHeartTextGap], isNull);
      expect(values[SettingsKeys.overlayGlowEnabled], isNull);
    });
  });
}
