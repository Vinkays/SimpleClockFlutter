import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// 持久化存储：窗口大小/位置、置顶状态、外观颜色。
///
/// 对应原 Electron 版 SimpleStore（app-config.json），
/// 使用 shared_preferences 在三个桌面平台落地。
class StoreService {
  static const String kWindowSize = 'windowSize';
  static const String kWindowPosition = 'windowPosition';
  static const String kAlwaysOnTop = 'isAlwaysOnTop';
  static const String kAppearanceBg = 'appearance.bgColor';
  static const String kAppearanceText = 'appearance.textColor';
  static const String kTextFontFamily = 'appearance.textFontFamily';
  static const String kLanguage = 'language';
  static const String kSingleInstancePort = 'singleInstancePort';
  static const String kAutoStartInitialized = 'autoStartInitialized';
  static const String kUpdateRemindHours = 'update.remindIntervalHours';
  static const String kUpdateSnoozeVersion = 'update.snoozeVersion';
  static const String kUpdateSnoozeUntil = 'update.snoozeUntil';
  static const String kDebugLogEnabled = 'debugLogEnabled';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存的窗口大小；无记录或非法时返回 null。
  Size? get windowSize {
    final raw = _prefs?.getStringList(kWindowSize);
    if (raw == null || raw.length != 2) return null;
    final w = double.tryParse(raw[0]);
    final h = double.tryParse(raw[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return Size(w, h);
  }

  Future<void> setWindowSize(Size size) async {
    await _prefs?.setStringList(kWindowSize, [
      size.width.toStringAsFixed(1),
      size.height.toStringAsFixed(1),
    ]);
  }

  /// 保存的窗口位置；无记录或非法时返回 null。
  Offset? get windowPosition {
    final raw = _prefs?.getStringList(kWindowPosition);
    if (raw == null || raw.length != 2) return null;
    final x = double.tryParse(raw[0]);
    final y = double.tryParse(raw[1]);
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Future<void> setWindowPosition(Offset pos) async {
    await _prefs?.setStringList(kWindowPosition, [
      pos.dx.toStringAsFixed(1),
      pos.dy.toStringAsFixed(1),
    ]);
  }

  bool get isAlwaysOnTop => _prefs?.getBool(kAlwaysOnTop) ?? false;

  Future<void> setIsAlwaysOnTop(bool value) async {
    await _prefs?.setBool(kAlwaysOnTop, value);
  }

  Color? get bgColor {
    final v = _prefs?.getInt(kAppearanceBg);
    return v == null ? null : Color(v);
  }

  Color? get textColor {
    final v = _prefs?.getInt(kAppearanceText);
    return v == null ? null : Color(v);
  }

  Future<void> setAppearance(Color bg, Color text) async {
    await _prefs?.setInt(kAppearanceBg, bg.toARGB32());
    await _prefs?.setInt(kAppearanceText, text.toARGB32());
  }

  /// 保存的文字字体（null 表示使用系统默认字体）。
  String? get textFontFamily => _prefs?.getString(kTextFontFamily);

  Future<void> setTextFontFamily(String? family) async {
    if (family == null) {
      await _prefs?.remove(kTextFontFamily);
    } else {
      await _prefs?.setString(kTextFontFamily, family);
    }
  }

  /// 保存的语言（'system' | 'zh' | 'en'；null 视为跟随系统）。
  String? get language => _prefs?.getString(kLanguage);

  Future<void> setLanguage(String language) async {
    await _prefs?.setString(kLanguage, language);
  }

  /// 单实例锁使用的端口号（null 表示尚未记录）。
  int? get singleInstancePort => _prefs?.getInt(kSingleInstancePort);

  Future<void> setSingleInstancePort(int port) async {
    await _prefs?.setInt(kSingleInstancePort, port);
  }

  /// 是否已执行过「首次启动默认开启自启动」。
  /// 标记写入后不再干预用户后续在菜单中的开启/移除选择。
  bool get isAutoStartInitialized =>
      _prefs?.getBool(kAutoStartInitialized) ?? false;

  Future<void> setAutoStartInitialized(bool value) async {
    await _prefs?.setBool(kAutoStartInitialized, value);
  }

  /// 「更新提醒间隔」小时数（默认 48，见 [UpdateConfig.defaultRemindHours]）。
  int get updateRemindHours => _prefs?.getInt(kUpdateRemindHours) ?? 48;

  Future<void> setUpdateRemindHours(int hours) async {
    await _prefs?.setInt(kUpdateRemindHours, hours);
  }

  /// 最近一次「稍后」的版本号（null 表示无记录）。
  String? get updateSnoozeVersion => _prefs?.getString(kUpdateSnoozeVersion);

  /// 最近一次「稍后」的冷却到期时间（epoch 毫秒；null 表示无记录）。
  int? get updateSnoozeUntil => _prefs?.getInt(kUpdateSnoozeUntil);

  Future<void> setUpdateSnooze(String version, int untilMillis) async {
    await _prefs?.setString(kUpdateSnoozeVersion, version);
    await _prefs?.setInt(kUpdateSnoozeUntil, untilMillis);
  }

  /// 清除冷却记录（手动检查更新 / 调整提醒间隔时调用，便于本地测试）。
  Future<void> clearUpdateSnooze() async {
    await _prefs?.remove(kUpdateSnoozeVersion);
    await _prefs?.remove(kUpdateSnoozeUntil);
  }

  /// 调试日志开关（默认关）。
  bool get debugLogEnabled => _prefs?.getBool(kDebugLogEnabled) ?? false;

  Future<void> setDebugLogEnabled(bool value) async {
    await _prefs?.setBool(kDebugLogEnabled, value);
  }
}
