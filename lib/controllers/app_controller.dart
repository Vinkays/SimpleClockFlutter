import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:window_manager/window_manager.dart';

import '../services/log_service.dart';
import '../services/single_instance_service.dart';
import '../services/store_service.dart';
import '../services/time_format_service.dart';
import '../services/tray_service.dart';

/// 应用全局状态：外观颜色、锁定、置顶、窗口几何信息。
///
/// 状态变化通过 [ChangeNotifier] 通知界面刷新；
/// 窗口系统调用集中在 [windowManager]（window_manager 包）。
class AppController extends ChangeNotifier {
  AppController(
    this.store, {
    Future<bool?> Function()? detectSystem12Hour,
  }) : _detectSystem12Hour =
            detectSystem12Hour ?? TimeFormatService.detectSystem12Hour;

  final StoreService store;

  /// 系统时间制式检测函数（测试可注入桩实现，默认走 [TimeFormatService]）。
  final Future<bool?> Function() _detectSystem12Hour;

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

  /// 时间制式：'system'（跟随系统）| '12h' | '24h'。
  String _timeFormat = 'system';
  String get timeFormat => _timeFormat;

  /// 系统检测到的默认时间制式（true=12 小时制，false=24 小时制，null=检测失败）。
  bool? _system12Hour;
  bool? get system12Hour => _system12Hour;

  /// 实际生效的是否使用 12 小时制（决定 AM/PM 的显示）。
  ///
  /// 「跟随系统」时用启动时的检测结果；检测失败回落 24 小时制
  /// （保持既有显示习惯，不强制改变用户已熟悉的界面）。
  bool get effective12Hour {
    return switch (_timeFormat) {
      '12h' => true,
      '24h' => false,
      _ => _system12Hour ?? false,
    };
  }

  /// 「更新提醒间隔」小时数（「稍后」后该版本冷却多久再提示）。
  int _updateRemindHours = 48;
  int get updateRemindHours => _updateRemindHours;

  /// 调试日志开关（默认关；开启后更新检查链路落盘，供远程诊断）。
  bool _debugLogEnabled = false;
  bool get debugLogEnabled => _debugLogEnabled;

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
    _timeFormat = store.timeFormat;
    _system12Hour = await _detectSystem12Hour();
    _updateRemindHours = store.updateRemindHours;
    _debugLogEnabled = store.debugLogEnabled;
    LogService.instance.setEnabled(_debugLogEnabled);
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

  /// 设置时间制式（'system' | '12h' | '24h'），持久化并广播。
  void setTimeFormat(String value) {
    if (value == _timeFormat) return;
    _timeFormat = value;
    store.setTimeFormat(value);
    notifyListeners();
  }

  /// 设置「更新提醒间隔」小时数，持久化并广播。
  /// 同时清除该版本的冷却记录：调整间隔 = 用户期待新的提醒节奏，
  /// 旧的「稍后」冷却不应继续拦截提醒。
  void setUpdateRemindHours(int hours) {
    if (hours == _updateRemindHours) return;
    _updateRemindHours = hours;
    store.setUpdateRemindHours(hours);
    store.clearUpdateSnooze();
    notifyListeners();
  }

  /// 切换调试日志开关，持久化并同步 LogService。
  void setDebugLogEnabled(bool value) {
    if (value == _debugLogEnabled) return;
    _debugLogEnabled = value;
    store.setDebugLogEnabled(value);
    LogService.instance.setEnabled(value);
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
      if (Platform.isMacOS) {
        // macOS 多桌面：置顶窗口默认只在当前 Space 生效，切到新桌面
        // 会失去置顶；同步设置"所有桌面可见"（canJoinAllSpaces）
        await windowManager.setVisibleOnAllWorkspaces(_isAlwaysOnTop);
      }
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
  Future<void> quitApp() async {
    if (_quitting) return;
    _quitting = true;
    await _singleInstance?.dispose();
    await TrayService.instance.destroy();
    await persistWindowState();
    try {
      await windowManager.destroy();
    } catch (_) {}
    // Flutter Windows 引擎的优雅关闭（PostQuitMessage 之后）实测耗时约 10 秒；
    // 清理均已完成，直接强制终止进程避免退出延迟，OS 会回收窗口与资源句柄。
    exit(0);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }
}
