import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../../services/font_service.dart';
import '../widgets/modal_shell.dart';

/// 右键菜单面板：自包含模态外壳（[ModalShell]），只负责菜单内容。
///
/// 窗口太小时由调用方（ClockPage）负责临时撑大窗口；
/// 内容过长时由 [ModalShell] 内部滚动保护，任意窗口尺寸下不溢出。
class MenuPanel extends StatefulWidget {
  const MenuPanel({
    super.key,
    required this.controller,
    required this.autoLaunchSupported,
    required this.autoLaunchEnabled,
    required this.onPickTextColor,
    required this.onPickBgColor,
    required this.onPickFont,
    required this.onPickLanguage,
    required this.onPickTimeFormat,
    required this.onPickRemindInterval,
    required this.onAbout,
    required this.onToggleDebugLog,
    required this.onToggleLock,
    required this.onToggleTop,
    required this.onToggleAutoLaunch,
    required this.onQuit,
    required this.onClose,
  });

  final AppController controller;
  final bool autoLaunchSupported;
  final bool autoLaunchEnabled;
  final VoidCallback onPickTextColor;
  final VoidCallback onPickBgColor;
  final VoidCallback onPickFont;
  final VoidCallback onPickLanguage;

  /// 打开「时间制式」面板。
  final VoidCallback onPickTimeFormat;
  final VoidCallback onPickRemindInterval;

  /// 打开「关于我们」面板。
  final VoidCallback onAbout;

  /// 切换调试日志开关。
  final VoidCallback onToggleDebugLog;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleTop;
  final VoidCallback onToggleAutoLaunch;
  final VoidCallback onQuit;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onClose;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  // 系统字体列表：仅用于菜单「字体」行的当前字体显示名
  // （字体选择面板自身独立加载列表）。
  List<FontChoice> _fonts = const [FontChoice(null, '')];

  @override
  void initState() {
    super.initState();
    _loadFontsForMenu();
  }

  Future<void> _loadFontsForMenu() async {
    final system = await FontService().loadSystemFonts();
    if (!mounted) return;
    setState(() {
      _fonts = [const FontChoice(null, ''), ...system];
    });
  }

  /// 当前字体在菜单「字体」行右侧的显示名。
  String get _currentFontLabel {
    final family = widget.controller.textFontFamily;
    if (family == null) return AppStrings.of(context)['defaultFont']!;
    for (final c in _fonts) {
      if (c.family == family) return c.label;
    }
    return family;
  }

  /// 当前语言在菜单「语言」行右侧的显示。
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

  /// 当前时间制式在菜单「时间制式」行右侧的显示。
  String get _currentTimeFormatLabel {
    final s = AppStrings.of(context);
    switch (widget.controller.timeFormat) {
      case '12h':
        return s['time12Hour']!;
      case '24h':
        return s['time24Hour']!;
      default:
        return s['timeFollowSystem']!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = AppStrings.of(context);
    final itemHeight = 34.0;
    return ModalShell(
      width: 220,
      fg: controller.textColor,
      bg: controller.bgColor,
      textFontFamily: controller.textFontFamily,
      onTapOutside: widget.onClose,
      child: Column(
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
          _MenuRow(
            label: s['menuTimeFormat']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            trailing: Text(
              _currentTimeFormatLabel,
              style: TextStyle(
                fontSize: 12,
                color: controller.textColor.withValues(alpha: 0.7),
              ),
            ),
            onTap: widget.onPickTimeFormat,
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
            label: s['menuRemindInterval']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            trailing: Text(
              '${controller.updateRemindHours}h',
              style: TextStyle(
                fontSize: 12,
                color: controller.textColor.withValues(alpha: 0.7),
              ),
            ),
            onTap: widget.onPickRemindInterval,
          ),
          _MenuRow(
            label: s['menuDebugLog']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            trailing: Text(
              controller.debugLogEnabled
                  ? s['debugLogOn']!
                  : s['debugLogOff']!,
              style: TextStyle(
                fontSize: 12,
                color: controller.textColor.withValues(alpha: 0.7),
              ),
            ),
            onTap: widget.onToggleDebugLog,
          ),
          _MenuRow(
            label: s['menuAbout']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            onTap: widget.onAbout,
          ),
          _MenuRow(
            label: s['menuQuit']!,
            fg: controller.textColor,
            bg: controller.bgColor,
            height: itemHeight,
            onTap: widget.onQuit,
          ),
        ],
      ),
    );
  }
}

/// 菜单行：标签 + 可选尾部（色块/当前值文本）。
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.label,
    required this.fg,
    required this.bg,
    required this.height,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final Color fg;
  final Color bg;
  final double height;
  final VoidCallback onTap;
  final Widget? trailing;

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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _hovered ? hoverBg : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.fg,
                  ),
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

/// 菜单「颜色」行右侧的小色块。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}
