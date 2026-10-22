import 'package:flutter/material.dart';

/// 半透明模态遮罩（公共组件）：覆盖整个窗口，可选点击回调。
/// 用于菜单/面板、更新弹窗等所有模态层，保证层级行为一致。
class ModalShade extends StatelessWidget {
  const ModalShade({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
      ),
    );
  }
}
