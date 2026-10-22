import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../widgets/modal_shell.dart';

/// 语言选择面板：自包含模态外壳（[ModalShell]）。
class LangPanel extends StatelessWidget {
  const LangPanel({
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
    final current = controller.language;
    final rows = <(String, String, String)>[
      ('system', s['langFollowSystem']!, s['langFollowSystemDesc']!),
      ('zh', s['langChinese']!, s['langChineseDesc']!),
      ('en', s['langEnglish']!, 'English'),
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
        PanelHeader(title: s['menuLanguage']!, fg: fg, onBack: onBack),
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
      ),
    );
  }
}

/// 设置面板通用的标题行（返回按钮 + 标题）。
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    required this.fg,
    required this.onBack,
  });

  final String title;
  final Color fg;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: 18, color: fg),
            onPressed: onBack,
            tooltip: AppStrings.of(context)['backToMenu']!,
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
    );
  }
}
