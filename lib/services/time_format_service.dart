import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 系统时间制式（12 小时制 / 24 小时制）检测服务。
///
/// Flutter 无直接 API 读取系统 12/24 小时设置，这里按平台用原生方式读取：
/// - Windows：注册表 `HKCU\Control Panel\International\sTimeFormat` /
///   `sShortTime`（含小写 `h` = 12 小时制，大写 `H` = 24 小时制），
///   纯 Dart 实现（win32_registry），无需原生代码；
/// - macOS：`defaults read -g AppleICUForce24HourTime` /
///   `AppleICUForce12HourTime`（两个强制键均未设置时，读取用户语言环境的
///   `AppleICUDateFormatStrings` 日期格式串，仍无法判断则返回 null）；
/// - Linux：GNOME 桌面环境 `org.gnome.desktop.interface clock-format`
///   （`12h` / `24h`），未命中再按 `LC_TIME`/`LC_ALL` 的常用 12 小时制区域匹配；
/// - 任一平台检测失败都返回 null，由调用方回落固定格式（24 小时制）。
class TimeFormatService {
  TimeFormatService._();

  /// 检测系统默认时间制式。
  ///
  /// 返回 `true` = 12 小时制，`false` = 24 小时制，`null` = 检测失败/未知。
  static Future<bool?> detectSystem12Hour() async {
    if (Platform.isWindows) return _detectWindows();
    if (Platform.isMacOS) return _detectMacOS();
    if (Platform.isLinux) return _detectLinux();
    return null;
  }

  // ---- Windows：注册表 ----

  static bool? _detectWindows() {
    try {
      final key = Registry.openPath(
        RegistryHive.currentUser,
        path: r'Control Panel\International',
      );
      // 优先 sTimeFormat（完整时间格式，含 h/H），缺失/为空再回落 sShortTime
      var format = key.getStringValue('sTimeFormat');
      if (format == null || format.isEmpty) {
        format = key.getStringValue('sShortTime');
      }
      key.close();
      return parseWindowsTimeFormat(format);
    } catch (_) {
      return null;
    }
  }

  /// 解析 Windows 时间格式串（含 `h` = 12 小时制，`H` = 24 小时制）。
  ///
  /// 单引号内的字面文本（如 `'h'`）不是占位符，判断前先剔除。
  /// 无法识别（null / 空 / 既无 h 也无 H）返回 null。
  static bool? parseWindowsTimeFormat(String? format) {
    if (format == null || format.isEmpty) return null;
    final cleaned = format.replaceAll(RegExp(r"'.*?'"), '');
    if (cleaned.contains('h')) return true;
    if (cleaned.contains('H')) return false;
    return null;
  }

  // ---- macOS：NSUserDefaults ----

  static Future<bool?> _detectMacOS() async {
    // 强制键优先：AppleICUForce24HourTime=1 → 24 小时制；=0 → 12 小时制
    final force24 = await _defaultsReadInt('AppleICUForce24HourTime');
    if (force24 == 1) return false;
    if (force24 == 0) return true;
    final force12 = await _defaultsReadInt('AppleICUForce12HourTime');
    if (force12 == 1) return true;
    if (force12 == 0) return false;

    // 均未设置：跟随用户语言环境的日期格式串（如 "HH:mm:ss" / "h:mm:ss a"）
    final dateFormats = await _defaultsReadString('AppleICUDateFormatStrings');
    if (dateFormats != null && dateFormats.isNotEmpty) {
      final parsed = parseIcuFormat(dateFormats);
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// 解析 macOS ICU 日期格式输出（含 `h` = 12 小时制，`H` = 24 小时制）。
  static bool? parseIcuFormat(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('h')) return true;
    if (raw.contains('H')) return false;
    return null;
  }

  static Future<int?> _defaultsReadInt(String key) async {
    try {
      final result = await Process.run('defaults', ['read', '-g', key]);
      if (result.exitCode != 0) return null;
      final value = result.stdout.toString().trim().toLowerCase();
      if (value == '1' || value == 'yes' || value == 'true') return 1;
      if (value == '0' || value == 'no' || value == 'false') return 0;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultsReadString(String key) async {
    try {
      final result = await Process.run('defaults', ['read', '-g', key]);
      if (result.exitCode != 0) return null;
      final value = result.stdout.toString().trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  // ---- Linux：GNOME dconf + locale ----

  static Future<bool?> _detectLinux() async {
    // 1) GNOME 桌面环境设置（org.gnome.desktop.interface clock-format）
    try {
      final result = await Process.run(
        'gsettings',
        const ['get', 'org.gnome.desktop.interface', 'clock-format'],
      );
      if (result.exitCode == 0) {
        final value = result.stdout.toString().trim().toLowerCase();
        if (value == "'12h'" || value == '"12h"') return true;
        if (value == "'24h'" || value == '"24h"') return false;
      }
    } catch (_) {
      // gsettings 不可用（非 GNOME 桌面）时继续走 locale
    }

    // 2) LC_TIME / LC_ALL 环境变量：常用 12 小时制区域匹配（尽力而为）
    final lcTime = Platform.environment['LC_TIME'] ??
        Platform.environment['LC_ALL'];
    if (lcTime != null && lcTime.isNotEmpty) {
      final lower = lcTime.toLowerCase();
      for (final tag in _locale12HourTags) {
        if (lower.startsWith(tag)) return true;
      }
    }
    return null;
  }

  /// 常用 12 小时制 locale 标签（LC_TIME 匹配用，尽力而为；未命中回落 24 小时制）。
  static const List<String> _locale12HourTags = [
    'en_us',
    'en_au',
    'en_ca',
    'en_nz',
    'en_ph',
    'en_in',
    'en_pk',
    'en_my',
    'en_sg',
    'hi_in',
    'ur_pk',
    'ar_eg',
    'ar_sa',
    'ko_kr',
    'ms_my',
    'fil_ph',
  ];
}
