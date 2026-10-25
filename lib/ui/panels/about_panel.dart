import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../../services/update_config.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 「关于我们」面板：自包含模态外壳（[ModalShell]），
/// 展示应用名与当前版本，并提供手动检查更新入口。
class AboutPanel extends StatelessWidget {
  const AboutPanel({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onCheckUpdateNow,
    required this.onOpenLogFile,
    required this.onTapOutside,
  });

  final AppController controller;
  final VoidCallback onBack;

  /// 手动检查更新（清除冷却后立即触发）。
  final VoidCallback onCheckUpdateNow;

  /// 用系统默认编辑器打开日志文件。
  final VoidCallback onOpenLogFile;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final fg = controller.textColor;
    final bg = controller.bgColor;
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
          PanelHeader(title: s['aboutTitle']!, fg: fg, onBack: onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 展示实际应用图标（assets/app_icon.png，黑底方形，加圆角更贴合图标块）
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s['aboutAppName']!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s['aboutVersionLabel']!} v${UpdateConfig.currentVersion}',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onCheckUpdateNow,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(s['aboutCheckUpdate']!),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onOpenLogFile,
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(s['aboutOpenLog']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
