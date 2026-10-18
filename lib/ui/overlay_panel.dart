import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../services/app_strings.dart';
import '../services/font_service.dart';

/// 覆盖层模式：右键菜单 / 选色 / 字体 / 语言。
enum OverlayMode { menu, pickingText, pickingBg, pickingFont, pickingLang }

/// 全窗口覆盖面板：右键菜单 + 内联 HSV 颜色选择器 + 字体选择。
///
/// 窗口太小时由调用方（ClockPage）负责临时撑大窗口；
/// 本组件自身带滚动保护（ConstrainedBox + SingleChildScrollView），
/// 任意窗口尺寸下内容都不会溢出（不再出现 bottom overflowed）。
class OverlayPanel extends StatefulWidget {
  const OverlayPanel({
    super.key,
    required this.controller,
    required this.mode,
    required this.autoLaunchSupported,
    required this.autoLaunchEnabled,
    required this.onPickTextColor,
    required this.onPickBgColor,
    required this.onPickFont,
    required this.onPickLanguage,
    required this.onToggleLock,
    required this.onToggleTop,
    required this.onToggleAutoLaunch,
    required this.onQuit,
    required this.onBackToMenu,
    required this.onApplyColor,
    required this.onApplyFont,
  });

  final AppController controller;
  final OverlayMode mode;
  final bool autoLaunchSupported;
  final bool autoLaunchEnabled;
  final VoidCallback onPickTextColor;
  final VoidCallback onPickBgColor;
  final VoidCallback onPickFont;
  final VoidCallback onPickLanguage;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleTop;
  final VoidCallback onToggleAutoLaunch;
  final VoidCallback onQuit;
  final VoidCallback onBackToMenu;
  final void Function(Color color, bool isText) onApplyColor;
  final void Function(String? family) onApplyFont;

  @override
  State<OverlayPanel> createState() => _OverlayPanelState();
}

class _OverlayPanelState extends State<OverlayPanel> {
  late HSVColor _hsv;
  bool _isText = false;

  // ---- 系统字体列表（打开字体面板时异步加载）----
  List<FontChoice> _fonts = const [FontChoice(null, '')];
  bool _fontsLoaded = false;
  String _fontQuery = '';

  static const List<Color> _presets = [
    Color(0xFF000000),
    Color(0xFF555555),
    Color(0xFF888888),
    Color(0xFFCCCCCC),
    Color(0xFFFFFFFF),
    Color(0xFFFF0000),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _syncPickerState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    final system = await FontService().loadSystemFonts();
    if (!mounted) return;
    setState(() {
      // 首项“默认字体”的显示名在 _FontRow 渲染时按当前语言动态生成
      _fonts = [const FontChoice(null, ''), ...system];
      _fontsLoaded = true;
    });
  }

  @override
  void didUpdateWidget(OverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncPickerState();
    }
  }

  void _syncPickerState() {
    _isText = widget.mode != OverlayMode.pickingBg;
    _hsv = HSVColor.fromColor(
      _isText ? widget.controller.textColor : widget.controller.bgColor,
    );
  }

  bool get _picking => widget.mode != OverlayMode.menu;

  String get _hex {
    final value = _hsv.toColor().toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final winSize = MediaQuery.sizeOf(context);
    final fg = widget.controller.textColor;
    final bg = widget.controller.bgColor;
    final cardWidth = _picking ? 300.0 : 220.0;
    final maxWidth = math.max(120.0, winSize.width - 8);
    final maxHeight = math.max(100.0, winSize.height - 8);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Material(
          color: Colors.transparent,
          // 面板文字字体直接注入（不依赖主题传播），
          // 覆盖菜单/选色/字体面板里的所有普通 Text 与输入框
          child: DefaultTextStyle.merge(
            style: TextStyle(fontFamily: widget.controller.textFontFamily),
            child: Container(
              width: cardWidth,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fg.withValues(alpha: 0.15)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: _buildBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (widget.mode) {
      case OverlayMode.menu:
        return _buildMenu();
      case OverlayMode.pickingFont:
        return _buildFontPicker();
      case OverlayMode.pickingLang:
        return _buildLangPicker();
      case OverlayMode.pickingText:
      case OverlayMode.pickingBg:
        return _buildPicker();
    }
  }

  // ---- 菜单模式 ----

  String get _currentFontLabel {
    final family = widget.controller.textFontFamily;
    if (family == null) return AppStrings.of(context)['defaultFont']!;
    for (final c in _fonts) {
      if (c.family == family) return c.label;
    }
    return family;
  }

  Widget _buildMenu() {
    final controller = widget.controller;
    final s = AppStrings.of(context);
    final itemHeight = 34.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuRow(
          label: s['menuTextColor']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          trailing: _Swatch(color: controller.textColor),
          onTap: widget.onPickTextColor,
        ),
        _MenuRow(
          label: s['menuBgColor']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          trailing: _Swatch(color: controller.bgColor),
          onTap: widget.onPickBgColor,
        ),
        _MenuRow(
          label: s['menuFont']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          trailing: Text(
            _currentFontLabel,
            style: TextStyle(
              fontSize: 12,
              color: controller.textColor.withValues(alpha: 0.7),
            ),
          ),
          onTap: widget.onPickFont,
        ),
        _MenuRow(
          label: controller.isLocked ? s['menuUnlock']! : s['menuLock']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          onTap: widget.onToggleLock,
        ),
        _MenuRow(
          label: controller.isAlwaysOnTop ? s['menuUnpin']! : s['menuPin']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          onTap: widget.onToggleTop,
        ),
        _MenuRow(
          label: s['menuLanguage']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          trailing: Text(
            _currentLanguageLabel,
            style: TextStyle(
              fontSize: 12,
              color: controller.textColor.withValues(alpha: 0.7),
            ),
          ),
          onTap: widget.onPickLanguage,
        ),
        if (widget.autoLaunchSupported)
          _MenuRow(
            label: widget.autoLaunchEnabled
                ? s['menuRemoveAutoStart']!
                : s['menuAutoStart']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            onTap: widget.onToggleAutoLaunch,
          ),
        _MenuRow(
          label: s['menuQuit']!,
          fg: controller.textColor,
          bg: controller.bgColor,
          height: itemHeight,
          onTap: widget.onQuit,
        ),
      ],
    );
  }

  /// 当前语言在菜单“语言”行右侧的显示。
  String get _currentLanguageLabel {
    final s = AppStrings.of(context);
    switch (widget.controller.language) {
      case 'zh':
        return s['langChinese']!;
      case 'en':
        return s['langEnglish']!;
      default:
        return s['langFollowSystem']!;
    }
  }

  /// 语言选择面板。
  Widget _buildLangPicker() {
    final controller = widget.controller;
    final s = AppStrings.of(context);
    final fg = controller.textColor;
    final bg = controller.bgColor;
    final current = controller.language;
    final rows = <(String, String, String)>[
      ('system', s['langFollowSystem']!, s['langFollowSystemDesc']!),
      ('zh', s['langChinese']!, s['langChineseDesc']!),
      ('en', s['langEnglish']!, 'English'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, size: 18, color: fg),
                onPressed: widget.onBackToMenu,
                tooltip: s['backToMenu']!,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  s['menuLanguage']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final (value, label, desc) in rows)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.setLanguage(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: value == current
                    ? Color.lerp(bg, const Color(0xFF2196F3), 0.15)
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: fg,
                              fontWeight: value == current
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: fg.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (value == current)
                      Icon(Icons.check, size: 16, color: fg),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---- 字体选择模式 ----

  List<FontChoice> get _visibleFonts {
    final q = _fontQuery.trim().toLowerCase();
    if (q.isEmpty) return _fonts;
    return _fonts
        .where((c) => c.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Widget _buildFontPicker() {
    final fg = widget.controller.textColor;
    final bg = widget.controller.bgColor;
    final s = AppStrings.of(context);
    final current = widget.controller.textFontFamily;
    final visible = _visibleFonts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, size: 18, color: fg),
                onPressed: widget.onBackToMenu,
                tooltip: s['backToMenu']!,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  s['pickFont']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 搜索框：字体多时快速定位
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  style: TextStyle(fontSize: 13, color: fg),
                  cursorColor: fg,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: false,
                    hintText: s['searchFonts']!,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: fg.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: fg.withValues(alpha: 0.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: fg.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: fg.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: fg.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _fontQuery = v),
                ),
              ),
              if (!_fontsLoaded)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      s['noFontsMatch']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                for (final choice in visible)
                  _FontRow(
                    choice: choice,
                    selected: choice.family == current,
                    fg: fg,
                    bg: bg,
                    defaultLabel: s['defaultFont']!,
                    onTap: () => widget.onApplyFont(choice.family),
                  ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  s['fontListHint']!,
                  style: TextStyle(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- 选色模式 ----

  Widget _buildPicker() {
    final current = _hsv.toColor();
    final fg = widget.controller.textColor;
    final s = AppStrings.of(context);
    final title = _isText ? s['pickTextColor']! : s['pickBgColor']!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, size: 18, color: fg),
                onPressed: widget.onBackToMenu,
                tooltip: s['backToMenu']!,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(height: 10),
              _sliderRow(s['hue']!, _hsv.hue, 0, 360, (v) {
                setState(() => _hsv = _hsv.withHue(v));
              }),
              _sliderRow(s['saturation']!, _hsv.saturation, 0, 1, (v) {
                setState(() => _hsv = _hsv.withSaturation(v));
              }),
              _sliderRow(s['brightness']!, _hsv.value, 0, 1, (v) {
                setState(() => _hsv = _hsv.withValue(v));
              }),
              const SizedBox(height: 6),
              Text(
                _hex,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 1,
                  color: fg,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((c) {
                  final selected = c.toARGB32() == current.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _hsv = HSVColor.fromColor(c)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.black26,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onBackToMenu,
                    child: Text(s['cancel']!, style: TextStyle(color: fg)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => widget.onApplyColor(current, _isText),
                    child: Text(s['confirm']!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.label,
    required this.fg,
    required this.bg,
    required this.height,
    this.trailing,
    required this.onTap,
  });

  final String label;
  final Color fg;
  final Color bg;
  final double height;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = Color.lerp(widget.bg, const Color(0xFFAAAAAA), 0.2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: widget.height,
          color: _hovered ? hoverBg : null,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.fg,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

class _FontRow extends StatefulWidget {
  const _FontRow({
    required this.choice,
    required this.selected,
    required this.fg,
    required this.bg,
    required this.defaultLabel,
    required this.onTap,
  });

  final FontChoice choice;
  final bool selected;
  final Color fg;
  final Color bg;

  /// “默认字体”在当前语言下的显示名（family 为 null 时使用）。
  final String defaultLabel;
  final VoidCallback onTap;

  @override
  State<_FontRow> createState() => _FontRowState();
}

class _FontRowState extends State<_FontRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = Color.lerp(widget.bg, const Color(0xFFAAAAAA), 0.2);
    final selectedBg = Color.lerp(widget.bg, const Color(0xFF2196F3), 0.15);
    // “默认字体”行：始终带浅边框 + 下划线，与普通字体选项区分
    final isDefault = widget.choice.family == null;
    final defaultBg =
        isDefault ? Color.lerp(widget.bg, widget.fg, 0.045) : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          // 颜色与边框统一放在 decoration 中，避免与 color 参数同时设置
          decoration: BoxDecoration(
            color: widget.selected
                ? selectedBg
                : (_hovered ? hoverBg : defaultBg),
            border: widget.selected
                ? Border.all(color: const Color(0xFF2196F3), width: 1)
                : isDefault
                    ? Border.all(color: widget.fg.withValues(alpha: 0.28))
                    : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.choice.family == null
                      ? widget.defaultLabel
                      : widget.choice.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.fg,
                    decoration:
                        isDefault ? TextDecoration.underline : null,
                    decorationColor: widget.fg.withValues(alpha: 0.45),
                    decorationThickness: 1.2,
                  ),
                ),
              ),
              Text(
                '12:34:56',
                style: TextStyle(
                  fontSize: 18,
                  color: widget.fg,
                  fontFamily: widget.choice.family,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
