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
}
