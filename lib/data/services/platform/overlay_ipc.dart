/// 悬浮窗进程间通信协议。
///
/// Windows 上悬浮窗运行在**独立进程**(原因见 `docs/troubleshooting.md` §10
/// 与项目根目录的 `TODO.md`),主进程与子进程通过**回环 TCP** 交换
/// "换行分隔的 JSON" 消息。选择回环而非命名管道/标准输入:实现零第三方依赖,
/// 且绑定 127.0.0.1 不会触发 Windows 防火墙授权弹窗。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 一条 IPC 消息。
typedef OverlayMessage = Map<String, Object?>;

/// 消息类型常量(主进程 → 子进程)。
abstract final class OverlayMessageType {
  /// 主进程要求显示悬浮窗。
  static const String show = 'show';

  /// 主进程要求隐藏悬浮窗(保留进程,便于快速再次显示)。
  static const String hide = 'hide';

  /// 心率/连接状态/样式快照。
  static const String state = 'state';

  /// 鼠标穿透开关。
  static const String passthrough = 'passthrough';

  /// 主进程退出,要求子进程自行退出。
  static const String quit = 'quit';

  /// 子进程 → 主进程:窗口已就绪,可以接收指令。
  static const String ready = 'ready';
}

/// 悬浮窗子进程的命令行参数。
abstract final class OverlayProcessArgs {
  /// 标示本进程是悬浮窗子进程。
  static const String flag = '--overlay-process';

  /// 回环端口,形如 `--overlay-port=12345`。
  static const String portPrefix = '--overlay-port=';
}

/// 从命令行参数解析悬浮窗子进程端口;不是子进程时返回 null。
///
/// 由 `main()` 在创建任何界面/引擎逻辑之前调用,用于路由到悬浮窗入口。
int? overlayProcessPort(List<String> args) {
  if (!args.contains(OverlayProcessArgs.flag)) return null;
  for (final arg in args) {
    if (!arg.startsWith(OverlayProcessArgs.portPrefix)) continue;
    return int.tryParse(arg.substring(OverlayProcessArgs.portPrefix.length));
  }
  return null;
}

/// 主/子进程共用的双向消息通道。
abstract interface class OverlayLink {
  /// 收到的消息(不会重复派发,内部已去重)。
  Stream<OverlayMessage> get messages;

  /// 连接是否可用。
  bool get isConnected;

  /// 发送一条消息;未连接时静默丢弃(状态类消息由调用方重发)。
  void send(OverlayMessage message);

  /// 关闭连接。
  Future<void> close();

  /// 连接结束(子进程退出或链路断开)。
  Future<void> get done;
}

/// 把 [Socket] 包装成"换行分隔 JSON"的消息通道。
///
/// 单条 socket 数据块可能包含半行或多行,因此统一走缓冲区按 `\n` 切分。
class JsonLineLink implements OverlayLink {
  /// 用已建立的 [socket] 创建通道。
  JsonLineLink(this._socket) {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          _onData,
          onError: (Object _) => _finish(),
          onDone: _finish,
          cancelOnError: true,
        );
  }

  final Socket _socket;
  late final StreamSubscription<String> _subscription;
  final StreamController<OverlayMessage> _messages =
      StreamController<OverlayMessage>.broadcast();
  final Completer<void> _done = Completer<void>();

  String _buffer = '';
  bool _connected = true;

  @override
  Stream<OverlayMessage> get messages => _messages.stream;

  /// 底层 socket(仅测试用于写入原始字节验证分帧)。
  @visibleForTesting
  Socket get debugSocket => _socket;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> get done => _done.future;

  void _onData(String chunk) {
    _buffer += chunk;
    var index = _buffer.indexOf('\n');
    while (index >= 0) {
      final line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);
      if (line.isNotEmpty) {
        final decoded = _decode(line);
        if (decoded != null && _messages.hasListener) {
          _messages.add(decoded);
        }
      }
      index = _buffer.indexOf('\n');
    }
  }

  /// 解析一行 JSON;非法消息丢弃而不抛出,避免脏数据打断通道。
  OverlayMessage? _decode(String line) {
    try {
      final value = jsonDecode(line);
      if (value is Map) return Map<String, Object?>.from(value);
    } on FormatException {
      // 忽略:协议外的数据不应导致悬浮窗退出。
    }
    return null;
  }

  @override
  void send(OverlayMessage message) {
    if (!_connected) return;
    try {
      _socket.write('${jsonEncode(message)}\n');
    } on Object {
      _finish();
    }
  }

  void _finish() {
    if (!_connected) return;
    _connected = false;
    if (!_done.isCompleted) _done.complete();
    unawaited(_subscription.cancel());
    unawaited(_messages.close());
  }

  @override
  Future<void> close() async {
    _finish();
    await _socket.flush().catchError((Object _) {});
    await _socket.close().catchError((Object _) {});
  }
}

/// 主进程侧的宿主链路接口(便于测试替换真实子进程)。
abstract interface class OverlayHost {
  /// 来自子进程的消息。
  Stream<OverlayMessage> get messages;

  /// 子进程是否已连接。
  bool get isConnected;

  /// 子进程退出信号;null 表示尚未启动。
  Future<void>? get exit;

  /// 绑定端口并拉起子进程,返回是否连接成功。
  Future<bool> start({required String executable});

  /// 发送消息(未连接时丢弃)。
  void send(OverlayMessage message);

  /// 结束链路并回收子进程。
  Future<void> close();
}

/// 拉起悬浮窗子进程的可替换函数(测试注入用)。
typedef OverlayProcessLauncher = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// 主进程侧链路:监听回环端口 → 拉起子进程 → 接受其连接。
///
/// 只有**第一个**连接会被采纳(防止重复实例串线)。
class OverlayHostLink implements OverlayHost {
  /// 创建主进程侧链路;[launcher] 仅供测试替换进程启动方式。
  OverlayHostLink({OverlayProcessLauncher? launcher})
    : _launch = launcher ?? _startProcess;

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments,
  ) => Process.start(executable, arguments);

  final OverlayProcessLauncher _launch;
  final StreamController<OverlayMessage> _messages =
      StreamController<OverlayMessage>.broadcast();

  ServerSocket? _server;
  Process? _process;
  JsonLineLink? _link;
  bool _closed = false;

  /// 子进程是否仍在运行。
  bool get isRunning => _process != null;

  /// 子进程已退出时完成。
  Future<void>? _exit;

  @override
  Future<void>? get exit => _exit;

  @override
  Stream<OverlayMessage> get messages => _messages.stream;

  @override
  bool get isConnected => _link?.isConnected ?? false;

  /// 子进程连接端口;未启动时为 null。
  int? get port => _server?.port;

  /// 绑定端口并拉起子进程,等待其连接。
  ///
  /// [executable] 为当前可执行文件(同一 exe 以不同参数自举)。
  /// 返回 true 表示子进程已连接。
  @override
  Future<bool> start({required String executable}) async {
    if (_closed) return false;
    if (isConnected) return true;
    await _stopProcess();

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;

    final connected = Completer<bool>();
    // 端口在连接建立后即可关闭监听,避免长期占用。
    late final StreamSubscription<Socket> acceptSub;
    acceptSub = server.listen((socket) {
      if (connected.isCompleted) {
        unawaited(socket.close());
        return;
      }
      _link = JsonLineLink(socket);
      unawaited(acceptSub.cancel());
      unawaited(server.close());
      _server = null;
      connected.complete(true);
    });

    final process =
        await _launch(executable, [
          OverlayProcessArgs.flag,
          '${OverlayProcessArgs.portPrefix}${server.port}',
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw const ProcessException(
              'pulse_sight',
              <String>[],
              '悬浮窗进程启动超时',
            );
          },
        );
    _process = process;
    _exit = process.exitCode.then((_) {
      _process = null;
      _link = null;
      if (!connected.isCompleted) connected.complete(false);
    });

    // 子进程先连接、再进入就绪;超时视为启动失败(不阻塞主界面)。
    final ok = await connected.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
    if (!ok) {
      await _stopProcess();
      return false;
    }
    _pump(_link!);
    return true;
  }

  /// 把链路消息转发到对外的 [messages]。
  void _pump(JsonLineLink link) {
    link.messages.listen(
      (message) {
        if (!_messages.isClosed) _messages.add(message);
      },
      onError: (Object _) {},
      onDone: () {},
    );
  }

  @override
  void send(OverlayMessage message) => _link?.send(message);

  Future<void> _stopProcess() async {
    final process = _process;
    _process = null;
    _link = null;
    if (process != null) {
      process.kill();
      unawaited(process.exitCode.catchError((Object _) => -1));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _link?.send({'type': OverlayMessageType.quit});
    await _link?.close();
    _link = null;
    // 给子进程一点时间自行退出,超时强杀,避免残留窗口。
    final process = _process;
    if (process != null) {
      final exited = await process.exitCode
          .timeout(const Duration(milliseconds: 1200))
          .then((_) => true)
          .catchError((Object _) => false);
      if (!exited) process.kill();
    }
    await _stopProcess();
    await _server?.close();
    _server = null;
    if (!_messages.isClosed) await _messages.close();
  }
}

/// 子进程侧链路:连接主进程给出的回环端口。
class OverlayClientLink implements OverlayLink {
  JsonLineLink? _link;

  @override
  Stream<OverlayMessage> get messages =>
      _link?.messages ?? const Stream<OverlayMessage>.empty();

  @override
  bool get isConnected => _link?.isConnected ?? false;

  @override
  Future<void> get done => _link?.done ?? Future<void>.value();

  /// 连接主进程;失败时抛出 [SocketException],由调用方决定是否重试。
  Future<void> connect(int port) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 5),
    );
    _link = JsonLineLink(socket);
  }

  @override
  void send(OverlayMessage message) => _link?.send(message);

  @override
  Future<void> close() async {
    await _link?.close();
    _link = null;
  }
}
