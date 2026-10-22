import 'package:flutter/material.dart';

import '../../services/app_strings.dart';
import '../../services/update_config.dart';
import '../../services/update_service.dart';
import 'modal_shell.dart';

/// 更新弹窗固定字体：不跟随用户自选字体。
/// Windows 用微软雅黑，其余平台经 fontFamilyFallback 依次回退系统字体。
const String kDialogFontFamily = 'Microsoft YaHei';
const List<String> kDialogFontFallback = [
  'PingFang SC',
  'Noto Sans CJK SC',
  'WenQuanYi Micro Hei',
];

/// 更新提示卡片：自包含模态外壳（[ModalShell]），绕开系统 Dialog
/// 在工具窗/失焦/缩放下的渲染异常；遮罩点击行为由 [onTapOutside] 决定
/// （防误触时传空回调，关闭必须明确点「稍后」或「立即更新」）。
class UpdatePromptCard extends StatelessWidget {
  const UpdatePromptCard({
    super.key,
    required this.info,
    required this.onLater,
    required this.onNow,
    required this.onTapOutside,
  });

  final ReleaseInfo info;
  final VoidCallback onLater;
  final VoidCallback onNow;
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ModalShell(
      width: 340,
      fg: Colors.white,
      bg: const Color(0xFF2A2A2A),
      textFontFamily: kDialogFontFamily,
      onTapOutside: onTapOutside,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题前加灯泡 icon（尺寸 22 > 标题 16，视觉上更突出）
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, size: 22, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s['updateAvailableTitle']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      // 深灰自绘底上固定白字，不继承浅色主题黑字
                      color: Colors.white,
                      // 固定系统字体，不跟随用户自选字体
                      fontFamily: kDialogFontFamily,
                      fontFamilyFallback: kDialogFontFallback,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 正文：版本号单独加大字号，比其余文字显眼一点
            Builder(builder: (context) {
              final template = s['updateAvailableBody']!;
              final curVer = 'v${UpdateConfig.currentVersion}';
              final newVer = info.tagName;
              // 按 {0} / {1} 占位符拆分模板，保证中英文均可用
              final seg0 = template.split('{0}');
              final seg1 = seg0[1].split('{1}');
              const baseStyle = TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontFamily: kDialogFontFamily,
                fontFamilyFallback: kDialogFontFallback,
              );
              const verStyle = TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontFamily: kDialogFontFamily,
                fontFamilyFallback: kDialogFontFallback,
              );
              return Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(text: seg0[0]),
                    TextSpan(text: curVer, style: verStyle),
                    TextSpan(text: seg1[0]),
                    TextSpan(text: newVer, style: verStyle),
                    TextSpan(text: seg1[1]),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onLater,
                  child: Text(
                    s['updateLater']!,
                    style: const TextStyle(
                      fontFamily: kDialogFontFamily,
                      fontFamilyFallback: kDialogFontFallback,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onNow,
                  child: Text(
                    s['updateNow']!,
                    style: const TextStyle(
                      fontFamily: kDialogFontFamily,
                      fontFamilyFallback: kDialogFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 更新下载进度卡片：自包含模态外壳（[ModalShell]）。
class UpdateProgressCard extends StatelessWidget {
  const UpdateProgressCard({
    super.key,
    required this.progress,
    required this.onCancel,
    required this.onTapOutside,
  });

  /// 下载进度 0~1。
  final double progress;
  final VoidCallback onCancel;
  final VoidCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return ModalShell(
      width: 340,
      fg: Colors.white,
      bg: const Color(0xFF2A2A2A),
      textFontFamily: kDialogFontFamily,
      onTapOutside: onTapOutside,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s['updateDownloading']!.replaceFirst('{0}', '$percent'),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                // 固定系统字体，不跟随用户自选字体
                fontFamily: kDialogFontFamily,
                fontFamilyFallback: kDialogFontFallback,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    s['updateLater']!,
                    style: const TextStyle(
                      // 固定系统字体，不跟随用户自选字体
                      fontFamily: kDialogFontFamily,
                      fontFamilyFallback: kDialogFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
