import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 时间显示：文本随窗口尺寸同步拉伸，铺满整个窗口。
///
/// 用 [CustomPaint] 直接在画布上绘制：先测量 80px 字号下文本的真实宽高，
/// 再按 `scaleX = 可用宽 / 文本宽`、`scaleY = 可用高 / 文本高` 非等比拉伸
/// （与原版 transform: scale(scaleX, scaleY) 行为一致）。
///
/// 之所以用 CustomPaint 而不是 widget 组合：
/// - 不受窗口宽度约束影响，文本永远单行（不会换行/分行）；
/// - 不参与布局溢出检测，窗口再小也不会出现 overflowed 警告；
/// - 上下左右留安全边距，文本边缘不会顶到窗口边界被裁剪；
/// - 支持任意 fontFamily（与 Text 一样），可通过右键菜单切换字体。
class ScaledClock extends StatelessWidget {
  const ScaledClock({
    super.key,
    required this.hour,
    required this.minute,
    required this.second,
    required this.textColor,
    this.textFontFamily,
  });

  final String hour;
  final String minute;
  final String second;
  final Color textColor;

  /// 文字字体（null 表示系统默认字体）。
  final String? textFontFamily;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 80,
      color: textColor,
      height: 1.0,
      fontFamily: textFontFamily,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return CustomPaint(
      painter: ClockTextPainter(
        text: '$hour:$minute:$second',
        style: textStyle,
      ),
      size: Size.infinite,
    );
  }
}

/// 时钟文本的绘制器：测量文本后按窗口尺寸拉伸绘制。
class ClockTextPainter extends CustomPainter {
  ClockTextPainter({required this.text, required this.style});

  final String text;
  final TextStyle style;

  /// 文本边缘到窗口边界的距离（避免贴边被裁剪）。
  static const double edgeMargin = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    // 取字形的实际视觉边界（而非整个行盒）：
    // 行盒包含字体的 ascent/descent 空白，而数字字形只占行盒上半部分，
    // 若按行盒居中，不同字体会明显偏上（特殊字体尤甚）。
    // 用 getBoxesForSelection 拿到每个字形簇的边界，合并出紧致视觉范围。
    var hLeft = 0.0;
    var hRight = painter.width;
    var vTop = 0.0;
    var vBottom = painter.height;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    if (boxes.isNotEmpty) {
      hLeft = boxes.map((b) => b.left).reduce(math.min);
      hRight = boxes.map((b) => b.right).reduce(math.max);
      vTop = boxes.map((b) => b.top).reduce(math.min);
      vBottom = boxes.map((b) => b.bottom).reduce(math.max);
    }
    final visualW = math.max(1.0, hRight - hLeft);
    final visualH = math.max(1.0, vBottom - vTop);
    final availW = math.max(1.0, size.width - edgeMargin * 2);
    final availH = math.max(1.0, size.height - edgeMargin * 2);
    final scaleX = availW / visualW;
    final scaleY = availH / visualH;
    final visualCenterX = (hLeft + hRight) / 2;
    final visualCenterY = (vTop + vBottom) / 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scaleX, scaleY);
    painter.paint(canvas, Offset(-visualCenterX, -visualCenterY));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ClockTextPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.style != style;
}
