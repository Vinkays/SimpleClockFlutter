import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:window_manager/window_manager.dart';

import '../services/single_instance_service.dart';
import '../services/store_service.dart';
import '../services/tray_service.dart';

/// 应用全局状态：外观颜色、锁定、置顶、窗口几何信息。
///
/// 状态变化通过 [ChangeNotifier] 通知界面刷新；
/// 窗口系统调用集中在 [windowManager]（window_manager 包）。
class AppController extends ChangeNotifier {
  AppController(this.store);

  final StoreService store;

  /// 单实例锁服务（由 main 启动时挂载，退出时释放端口）。
  SingleInstanceService? _singleInstance;

  static const Size kDefaultWindowSize = Size(350, 100);
  static const Size kMinWindowSize = Size(50, 30);
  static const Size kMaxWindowSize = Size(99999, 99999);

  Color _bgColor = const Color(0xFFFFFFFF);
  Color get bgColor => _bgColor;

  Color _textColor = const Color(0xFF000000);
  Color get textColor => _textColor;

  /// 文字字体（null 表示系统默认字体）。
  String? _textFontFamily;
  String? get textFontFamily => _textFontFamily;

  /// 界面语言：'system'（跟随系统）| 'zh' | 'en'。
  String _language = 'system';
  String get language => _language;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isAlwaysOnTop = false;
  bool get isAlwaysOnTop => _isAlwaysOnTop;

  Size? _windowSize;
  Size? get windowSize => _windowSize;

  Offset? _windowPosition;
  Offset? get windowPosition => _windowPosition;

  bool _quitting = false;

  Timer? _persistDebounce;

  /// 从持久化存储恢复状态。
  Future<void> init() async {
    _windowSize = store.windowSize;
    _windowPosition = store.windowPosition;
    _isAlwaysOnTop = store.isAlwaysOnTop;
    _bgColor = store.bgColor ?? const Color(0xFFFFFFFF);
    _textColor = store.textColor ?? const Color(0xFF000000);
    _textFontFamily = store.textFontFamily;
    _language = store.language ?? 'system';
  }

  /// 设置外观（背景色 / 文字颜色），持久化并广播。
  void setAppearance(Color bg, Color text) {
    _bgColor = bg;
    _textColor = text;
    store.setAppearance(bg, text);
    notifyListeners();
  }

  /// 设置文字字体（null 表示系统默认），持久化并广播。
  void setTextFontFamily(String? family) {
    if (family == _textFontFamily) return;
    _textFontFamily = family;
    store.setTextFontFamily(family);
    notifyListeners();
  }

  /// 设置界面语言（'system' | 'zh' | 'en'），持久化并广播。
  void setLanguage(String language) {
    if (language == _language) return;
    _language = language;
    store.setLanguage(language);
    notifyListeners();
  }

  /// 切换锁定：锁定时禁止拖动与调整窗口大小。
  Future<void> toggleLock() async {
    _isLocked = !_isLocked;
    try {
      await windowManager.setResizable(!_isLocked);
    } catch (_) {}
    notifyListeners();
  }

  /// 切换窗口置顶。
  Future<void> toggleAlwaysOnTop() async {
    _isAlwaysOnTop = !_isAlwaysOnTop;
    try {
      await windowManager.setAlwaysOnTop(_isAlwaysOnTop);
    } catch (_) {}
    store.setIsAlwaysOnTop(_isAlwaysOnTop);
    notifyListeners();
  }

  /// 窗口尺寸变化（由 WindowListener 回调触发）。
  Future<void> handleWindowResize() async {
    try {
      final size = await windowManager.getSize();
      _windowSize = size;
    } catch (_) {}
    _schedulePersist();
  }

  /// 窗口位置变化（由 WindowListener 回调触发）。
  Future<void> handleWindowMoved() async {
    try {
      final pos = await windowManager.getPosition();
      _windowPosition = pos;
    } catch (_) {}
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: 800),
      persistWindowState,
    );
  }

  /// 立即持久化窗口大小与位置（拖动结束 / 关闭窗口时调用）。
  Future<void> persistWindowState() async {
    _persistDebounce?.cancel();
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      _windowSize = size;
      _windowPosition = pos;
      await store.setWindowSize(size);
      await store.setWindowPosition(pos);
    } catch (_) {
      // 窗口已销毁等情况下静默忽略
    }
  }

  /// 挂载单实例锁服务（main 启动时调用；用于退出时释放端口）。
  void attachSingleInstance(SingleInstanceService service) {
    _singleInstance = service;
  }

  /// 退出应用：先释放单实例端口，再销毁托盘，持久化窗口状态，最后销毁窗口。
  /// 各步骤写时间日志到临时文件（诊断退出延迟用；确认后移除）。
  Future<void> quitApp() async {
    if (_quitting) return;
    _quitting = true;
    void log(String step) {
      try {
        final f = File('${Directory.systemTemp.path}/simple_clock_quit.log');
        f.writeAsStringSync(
          '[${DateTime.now().toIso8601String()}] $step\n',
          mode: FileMode.append,
        );
      } catch (_) {}
    }

    log('quit begin');
    await _singleInstance?.dispose();
    log('single instance disposed');
    await TrayService.instance.destroy();
    log('tray destroyed');
    await persistWindowState();
    log('window state persisted');
    try {
      await windowManager.destroy();
    } catch (_) {}
    log('window destroyed');
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }
}
