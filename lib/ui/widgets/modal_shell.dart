import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'modal_shade.dart';

/// 模态外壳（公共组件）：半透明遮罩 + 居中卡片 + 字体注入 + 滚动保护。
///
/// 菜单/各设置面板/更新弹窗/进度卡等所有模态层统一使用：
/// - 遮罩点击行为由 [onTapOutside] 决定（菜单=关闭、更新弹窗=防误触无操作等）；
/// - 卡片背景/边框/文字字体统一注入，面板自身只负责内容。
class ModalShell extends StatelessWidget {
  const ModalShell({
    super.key,
    required this.child,
    required this.width,
    required this.fg,
    required this.bg,
    this.textFontFamily,
    this.onTapOutside,
  });

  /// 卡片内要渲染的内容。
  final Widget child;

  /// 卡片宽度（内容自然高度；窗口过小时受 [ModalShell] 高度约束并滚动）。
  final double width;

  /// 卡片前景色（边框/文字主题色）。
  final Color fg;

  /// 卡片背景色。
  final Color bg;

  /// 注入卡片内普通 Text 与输入框的字体（null 表示不注入，跟随默认主题）。
  final String? textFontFamily;

  /// 遮罩点击回调（null 表示点击无操作，用于防误触场景）。
  final VoidCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    final winSize = MediaQuery.sizeOf(context);
    final maxWidth = math.max(120.0, winSize.width - 8);
    final maxHeight = math.max(100.0, winSize.height - 8);
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalShade(onTap: onTapOutside),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: Colors.transparent,
              // 面板文字字体直接注入（不依赖主题传播），
              // 覆盖菜单/各设置面板里的所有普通 Text 与输入框
              child: DefaultTextStyle.merge(
                style: TextStyle(fontFamily: textFontFamily),
                child: Container(
                  width: width,
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
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
