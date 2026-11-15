import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 系统已安装字体枚举服务。
///
/// macOS / Windows 经原生通道 `pulsesight/fonts` 枚举系统字体族
/// (CoreText / DirectWrite);其他平台暂不支持(返回空列表,
/// 界面仅显示“默认”)。
class FontListService {
  /// 创建服务;测试可注入 [loader] 替代真实通道调用。
  FontListService({Future<List<String>> Function()? loader})
    : _customLoader = loader;

  final Future<List<String>> Function()? _customLoader;

  static const MethodChannel _channel = MethodChannel('pulsesight/fonts');

  bool _loaded = false;
  List<String> _cache = const [];
  final Completer<void> _ready = Completer<void>();

  /// 系统字体族列表(懒加载,结果缓存;加载完成前返回空列表)。
  List<String> get fontFamilies => _cache;

  /// 字体列表加载完成的 Future。
  Future<void> get ready => _ready.future;

  /// 加载系统字体族列表;失败时静默返回空列表。
  ///
  /// 测试环境无绑定初始化,通道调用会抛 Error 而非 Exception,
  /// 因此这里捕获任意错误并静默降级。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      if (_customLoader != null) {
        _cache = _normalize(await _customLoader());
      } else if (Platform.isMacOS || Platform.isWindows) {
        final families = await _channel.invokeMethod<List<Object?>>('list');
        _cache = _normalize(families ?? const []);
      }
    } catch (_) {
      _cache = const [];
    }
    _ready.complete();
  }

  /// 去重并按大小写不敏感排序,统一各端返回顺序。
  static List<String> _normalize(Iterable<Object?> families) {
    return families.whereType<String>().toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
