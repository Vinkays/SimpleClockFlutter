import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 时间制式选择面板：自包含模态外壳（[ModalShell]）。
///
/// 三选一：「跟随系统 / 12 小时制 / 24 小时制」。
/// - 跟随系统：启动时按平台检测系统设置（Windows 注册表 / macOS defaults /
///   Linux gsettings），检测失败回落 24 小时制；
/// - 12 小时制：时钟秒数后显示 AM/PM（与数字同字号）；
/// - 24 小时制：不显示 AM/PM。
class TimeFormatPanel extends StatelessWidget {
  const TimeFormatPanel({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onTapOutside,
  });

  final AppController controller;
  final VoidCallback onBack;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final fg = controller.textColor;
    final bg = controller.bgColor;
    final current = controller.timeFormat;
    final rows = <(String, String, String)>[
      ('system', s['timeFollowSystem']!, s['timeFollowSystemDesc']!),
      ('12h', s['time12Hour']!, s['time12HourDesc']!),
      ('24h', s['time24Hour']!, s['time24HourDesc']!),
    ];
    return ModalShell(
      width: 300,
      fg: fg,
      bg: bg,
      textFontFamily: controller.textFontFamily,
      onTapOutside: onTapOutside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        PanelHeader(title: s['menuTimeFormat']!, fg: fg, onBack: onBack),
        const SizedBox(height: 4),
        for (final (value, label, desc) in rows)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.setTimeFormat(value),
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
      ),
    );
  }
}
