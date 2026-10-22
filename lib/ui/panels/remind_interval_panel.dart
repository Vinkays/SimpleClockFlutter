import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 更新提醒间隔选择面板：自包含模态外壳（[ModalShell]），内部为预设小时数 + 自定义输入。
class RemindIntervalPanel extends StatefulWidget {
  const RemindIntervalPanel({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onApplyRemindInterval,
    required this.onShowToast,
    required this.onTapOutside,
  });

  final AppController controller;
  final VoidCallback onBack;
  final void Function(int hours) onApplyRemindInterval;
  final void Function(String message) onShowToast;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  State<RemindIntervalPanel> createState() => _RemindIntervalPanelState();
}

class _RemindIntervalPanelState extends State<RemindIntervalPanel> {
  bool _customHoursEditing = false;
  bool _applying = false;
  final TextEditingController _customHoursController = TextEditingController();

  static const List<int> _presets = [6, 12, 24, 48, 72];

  @override
  void dispose() {
    _customHoursController.dispose();
    super.dispose();
  }

  /// 应用自定义小时数；非法输入（非数字 / 超出 1-8760）toast 提示并保持面板。
  ///
  /// 防重入：回车可能同时触发 onSubmitted 与失焦路径，首次调用后
  /// 清空输入框并置位 [_applying]，避免空字符串二次触发校验 toast。
  void _applyCustomHours(String raw) {
    if (_applying) return;
    _applying = true;
    final h = int.tryParse(raw.trim());
    if (h == null || h < 1 || h > 8760) {
      _applying = false;
      widget.onShowToast(AppStrings.of(context)['customHoursInvalid']!);
      return;
    }
    _customHoursEditing = false;
    _customHoursController.clear();
    widget.onApplyRemindInterval(h);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = AppStrings.of(context);
    final fg = controller.textColor;
    final bg = controller.bgColor;
    final current = controller.updateRemindHours;
    return ModalShell(
      width: 300,
      fg: fg,
      bg: bg,
      textFontFamily: controller.textFontFamily,
      onTapOutside: widget.onTapOutside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        PanelHeader(
          title: s['remindIntervalTitle']!,
          fg: fg,
          onBack: widget.onBack,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            s['remindIntervalDesc']!,
            style: TextStyle(
              fontSize: 10.5,
              color: fg.withValues(alpha: 0.55),
            ),
          ),
        ),
        for (final h in _presets)
          _RemindRow(
            label: _hoursLabel(s, h),
            selected: current == h,
            fg: fg,
            bg: bg,
            onTap: () => widget.onApplyRemindInterval(h),
          ),
        _RemindRow(
          label: s['hoursCustom']!,
          selected: _presets.contains(current) ? false : true,
          fg: fg,
          bg: bg,
          onTap: () => setState(() {
            // 重新进入编辑态：重置防重入标志，允许新一轮输入/修改
            _customHoursEditing = true;
            _applying = false;
          }),
          trailing: _customHoursEditing
              ? SizedBox(
                  width: 92,
                  height: 28,
                  child: TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 12, color: fg),
                    cursorColor: fg,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: s['customHoursHint']!,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.4),
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
                    onSubmitted: (v) => _applyCustomHours(v),
                    onEditingComplete: () =>
                        _applyCustomHours(_customHoursController.text),
                    controller: _customHoursController,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 预设小时数的显示文案（zh：'6 小时'；en：'6 hours'）。
  String _hoursLabel(Map<String, String> s, int hours) {
    return switch (hours) {
      6 => s['hours6']!,
      12 => s['hours12']!,
      24 => s['hours24']!,
      48 => s['hours48']!,
      72 => s['hours72']!,
      _ => '$hours h',
    };
  }
}

class _RemindRow extends StatefulWidget {
  const _RemindRow({
    required this.label,
    required this.selected,
    required this.fg,
    required this.bg,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_RemindRow> createState() => _RemindRowState();
}

class _RemindRowState extends State<_RemindRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = Color.lerp(widget.bg, const Color(0xFFAAAAAA), 0.2);
    final selectedBg = Color.lerp(widget.bg, const Color(0xFF2196F3), 0.15);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? selectedBg
                : (_hovered ? hoverBg : null),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.fg,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
              if (widget.selected)
                Icon(Icons.check, size: 16, color: widget.fg),
            ],
          ),
        ),
      ),
    );
  }
}
