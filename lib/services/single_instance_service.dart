import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'store_service.dart';

/// 单实例锁（纯 Dart，Windows / macOS / Linux 通用）。
///
/// 原理：本机随机端口占位 + 端口号持久化。
/// 首次启动随机绑定一个 loopback 端口，并把端口号写入存储；
/// 之后每次启动先读取端口号：
/// - 能连上该端口 → 已有实例在运行：通知它聚焦，本实例直接退出；
/// - 连不上且能重新绑定同一端口 → 前实例已退出，本实例接管；
/// - 绑定失败（端口被其它程序占用）→ 随机换新端口。
class SingleInstanceService {
  SingleInstanceService(this.store);

  final StoreService store;

  static const int _portRangeStart = 40000;
  static const int _portRangeEnd = 49999;
  static const int _maxAttempts = 20;

  ServerSocket? _server;
  bool _activated = false;
  void Function()? _onActivate;

  /// 尝试成为唯一实例。
  ///
  /// 返回 true：本实例是唯一运行实例，可继续启动；
  /// 返回 false：已有实例在运行，调用方应直接退出。
  ///
  /// [onActivate]：当本实例已运行时，又有新实例启动请求激活（用于聚焦窗口）。
  Future<bool> acquire({void Function()? onActivate}) async {
    _onActivate = onActivate;
    final saved = store.singleInstancePort;

    // 1) 已有端口记录：先探测是否还有实例在跑
    if (saved != null) {
      if (await _probe(saved)) {
        // 已有实例：通知它后本实例退出
        return false;
      }
      // 前实例已退出：尝试接管同一端口
      if (await _bind(saved)) return true;
    }

    // 2) 无记录或原端口不可用：随机绑定新端口
    final random = Random();
    for (var i = 0; i < _maxAttempts; i++) {
      final port =
          _portRangeStart + random.nextInt(_portRangeEnd - _portRangeStart + 1);
      if (await _bind(port)) return true;
    }

    // 3) 极端情况下绑不上也不阻塞启动（无单例保护，功能不受影响）
    return true;
  }

  /// 尝试连接指定端口：能连上说明有实例在监听。
  Future<bool> _probe(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 绑定端口成为监听者，成功后持久化端口号。
  Future<bool> _bind(int port) async {
    try {
      final server =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      _server!.listen(_handleConnection);
      await store.setSingleInstancePort(port);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 收到新实例的连接：通知激活（聚焦已有窗口）。
  void _handleConnection(Socket socket) {
    socket.destroy();
    if (!_activated) {
      _activated = true;
      _onActivate?.call();
    }
  }

  /// 释放端口（应用退出时调用；进程退出后 OS 也会自动回收，非必需）。
  Future<void> dispose() async {
    _activated = false;
    await _server?.close();
    _server = null;
  }
}
