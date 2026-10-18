import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

/// 一个可选的字体（family 为 null 表示使用系统默认字体）。
class FontChoice {
  const FontChoice(this.family, this.label);

  final String? family;
  final String label;
}

/// 读取本机已安装字体的服务。
///
/// - Windows：读取注册表 `HKLM\...\Windows NT\CurrentVersion\Fonts`，
///   拿到全部已安装字体名（纯 Dart 实现，无需原生代码）；
/// - macOS：扫描系统字体目录，文件名解析族名 + 常见族名修正表；
/// - Linux：调用 fontconfig 的 `fc-list` 枚举字体族名。
///   任一平台读取失败都会回退到通用候选列表，不会影响应用运行。
class FontService {
  /// 符号/装饰类字体，不适合作为时钟数字字体，直接过滤。
  static const Set<String> _excludedFonts = {
    'wingdings',
    'webdings',
    'symbol',
    'marlett',
    'mt extra',
    'ms outlook',
    'map symbols',
    'segoe mdl2 assets',
    'segoe ui symbol',
    'segoe ui emoji',
    'bookshelf symbol',
    'book antiqua',
    'old english text mt',
    'monotype sorts',
    'optical character recognition',
    'printer',
    'terminal',
  };

  /// 样式变体（如 "Arial Bold"、"Calibri Light Italic"）不是独立字体族名，
  /// 注册表 / 字体文件名里出现时直接过滤。
  static final RegExp _styleSuffix = RegExp(
    r'\s+(Bold|Italic|Light|Regular|SemiBold|SemiLight|Demi)$',
    caseSensitive: false,
  );

  /// 文件名中的样式变体（如 "HelveticaNeue-Bold.ttf"、"SFNS-Italic.ttf"）。
  static final RegExp _styleFileSuffix = RegExp(
    r'[-_](Bold|Italic|Light|Regular|Medium|SemiBold|SemiLight|Demi|Heavy|Thin)$',
    caseSensitive: false,
  );

  /// macOS 文件名与真实字体族名的常见偏差修正（尽力而为）。
  static const Map<String, String> _macFamilyRenames = {
    'PingFang': 'PingFang SC',
    'HelveticaNeue': 'Helvetica Neue',
    'Arial Unicode': 'Arial Unicode MS',
    'Noto Sans CJK': 'Noto Sans CJK SC',
    'Noto Serif CJK': 'Noto Serif CJK SC',
    'NotoSansCJK': 'Noto Sans CJK SC',
    'NotoSerifCJK': 'Noto Serif CJK SC',
  };

  /// macOS 系统字体目录（按优先级排列）。
  static const List<String> _macFontDirs = [
    '/System/Library/Fonts',
    '/System/Library/Fonts/Supplemental',
    '/Library/Fonts',
    '/Library/Fonts/Supplemental',
  ];

  /// 读取系统字体列表（去重、过滤符号字体，已按字母序排序）。
  Future<List<FontChoice>> loadSystemFonts() async {
    if (Platform.isWindows) {
      final names = _readWindowsFonts();
      if (names != null && names.isNotEmpty) {
        return _buildChoices(names, stripTypeSuffix: true, filterStyle: true);
      }
    } else if (Platform.isMacOS) {
      final names = _readMacFonts();
      if (names.isNotEmpty) {
        return _buildChoices(names,
            stripTypeSuffix: false, filterStyle: true, renameMap: _macFamilyRenames);
      }
    } else if (Platform.isLinux) {
      final names = await _readLinuxFonts();
      if (names != null && names.isNotEmpty) {
        return _buildChoices(names,
            stripTypeSuffix: false, filterStyle: false);
      }
    }
    return defaultCandidates;
  }

  // ---- Windows：注册表 ----

  List<String>? _readWindowsFonts() {
    try {
      final key = Registry.openPath(
        RegistryHive.localMachine,
        path: r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      );
      // 注意：map/where 是惰性的，必须先 toList() 求值完再 close 句柄，
      // 否则 close 后再遍历会因句柄失效抛异常
      final names = key.values
          .map((v) => v.name)
          .where((n) => n.isNotEmpty)
          .toList();
      key.close();
      return names;
    } catch (_) {
      return null;
    }
  }

  // ---- macOS：扫描系统字体目录 ----

  List<String> _readMacFonts() {
    const extensions = {'.ttf', '.otf', '.ttc', '.dfont'};
    final names = <String>[];
    for (final dir in _macFontDirs) {
      try {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        for (final f in d.listSync(followLinks: false)) {
          if (f is! File) continue;
          final name = f.path.split(Platform.pathSeparator).last;
          final dot = name.lastIndexOf('.');
          if (dot <= 0) continue;
          if (!extensions.contains(name.substring(dot).toLowerCase())) continue;
          final base = name.substring(0, dot);
          // 跳过隐藏文件 / 系统占位字体
          if (base.startsWith('.') || base.startsWith('._')) continue;
          names.add(base);
        }
      } catch (_) {
        // 单个目录读取失败不影响其它目录
      }
    }
    return names;
  }

  // ---- Linux：fc-list（fontconfig） ----

  Future<List<String>?> _readLinuxFonts() async {
    try {
      final result = await Process.run(
        'fc-list',
        const ['--format=%{family}\n'],
      );
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString();
      if (out.trim().isEmpty) return null;
      // 每个族名一行；多族字体（如 Noto Sans CJK 多语言变体）以逗号分隔
      return out
          .split('\n')
          .expand((e) => e.split(','))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ---- 统一清洗 ----

  List<FontChoice> _buildChoices(
    List<String> rawNames, {
    required bool stripTypeSuffix,
    required bool filterStyle,
    Map<String, String> renameMap = const {},
  }) {
    final result = <FontChoice>[];
    final seen = <String>{};
    for (final name in rawNames) {
      // 去掉注册表类型后缀，如 "Arial (TrueType)" -> "Arial"
      var family = name;
      if (stripTypeSuffix) {
        family = family.replaceAll(
          RegExp(r'\s*\((TrueType|OpenType)\)$'),
          '',
        );
      }
      family = family.trim();
      if (family.isEmpty) continue;
      // macOS 文件名 -> 真实族名修正
      if (renameMap.containsKey(family)) {
        family = renameMap[family]!;
      }
      final lower = family.toLowerCase();
      if (_excludedFonts.contains(lower)) continue;
      if (filterStyle) {
        if (_styleSuffix.hasMatch(family)) continue;
        if (_styleFileSuffix.hasMatch(family)) continue;
      }
      if (!seen.add(lower)) continue;
      result.add(FontChoice(family, family));
    }
    result.sort((a, b) =>
        a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return result;
  }

  /// 非 Windows 平台 / 读取失败时的通用候选。
  static const List<FontChoice> defaultCandidates = [
    FontChoice('Consolas', 'Consolas（等宽）'),
    FontChoice('Segoe UI', 'Segoe UI'),
    FontChoice('Arial', 'Arial（无衬线）'),
  ];
}
