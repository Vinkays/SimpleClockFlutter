import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../../services/font_service.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 字体选择面板：自包含模态外壳（[ModalShell]），内部为搜索框 + 系统字体列表。
class FontPanel extends StatefulWidget {
  const FontPanel({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onApplyFont,
    required this.onTapOutside,
  });

  final AppController controller;
  final VoidCallback onBack;
  final void Function(String? family) onApplyFont;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  State<FontPanel> createState() => _FontPanelState();
}

class _FontPanelState extends State<FontPanel> {
  // ---- 系统字体列表（打开字体面板时异步加载）----
  List<FontChoice> _fonts = const [FontChoice(null, '')];
  bool _fontsLoaded = false;
  String _fontQuery = '';

  @override
  void initState() {
    super.initState();
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

  List<FontChoice> get _visibleFonts {
    final q = _fontQuery.trim().toLowerCase();
    if (q.isEmpty) return _fonts;
    return _fonts
        .where((c) => c.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.controller.textColor;
    final bg = widget.controller.bgColor;
    final s = AppStrings.of(context);
    final current = widget.controller.textFontFamily;
    final visible = _visibleFonts;
    return ModalShell(
      width: 300,
      fg: fg,
      bg: bg,
      textFontFamily: widget.controller.textFontFamily,
      onTapOutside: widget.onTapOutside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        PanelHeader(title: s['pickFont']!, fg: fg, onBack: widget.onBack),
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
