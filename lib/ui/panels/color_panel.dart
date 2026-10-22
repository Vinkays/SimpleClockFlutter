import 'package:flutter/material.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 选色面板：自包含模态外壳（[ModalShell]），内部为预览色块 + HSV 滑杆 + 预设色 + 确认/取消。
class ColorPanel extends StatefulWidget {
  const ColorPanel({
    super.key,
    required this.controller,
    required this.isText,
    required this.onBack,
    required this.onApplyColor,
    required this.onTapOutside,
  });

  final AppController controller;

  /// true 选择文字颜色；false 选择背景色。
  final bool isText;
  final VoidCallback onBack;
  final void Function(Color color, bool isText) onApplyColor;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  State<ColorPanel> createState() => _ColorPanelState();
}

class _ColorPanelState extends State<ColorPanel> {
  late HSVColor _hsv;

  static const List<Color> _presets = [
    Color(0xFF000000),
    Color(0xFF555555),
    Color(0xFF888888),
    Color(0xFFCCCCCC),
    Color(0xFFFFFFFF),
    Color(0xFFFF0000),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(
      widget.isText ? widget.controller.textColor : widget.controller.bgColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _hsv.toColor();
    final fg = widget.controller.textColor;
    final s = AppStrings.of(context);
    final title = widget.isText ? s['pickTextColor']! : s['pickBgColor']!;
    return ModalShell(
      width: 300,
      fg: fg,
      bg: widget.controller.bgColor,
      textFontFamily: widget.controller.textFontFamily,
      onTapOutside: widget.onTapOutside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        PanelHeader(title: title, fg: fg, onBack: widget.onBack),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(height: 10),
              _sliderRow(s['hue']!, _hsv.hue, 0, 360, (v) {
                setState(() => _hsv = _hsv.withHue(v));
              }),
              _sliderRow(s['saturation']!, _hsv.saturation, 0, 1, (v) {
                setState(() => _hsv = _hsv.withSaturation(v));
              }),
              _sliderRow(s['brightness']!, _hsv.value, 0, 1, (v) {
                setState(() => _hsv = _hsv.withValue(v));
              }),
              const SizedBox(height: 6),
              Text(
                _hex,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  letterSpacing: 1,
                  color: fg,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((c) {
                  final selected = c.toARGB32() == current.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _hsv = HSVColor.fromColor(c)),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: selected ? Colors.blue : Colors.black26,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onBack,
                    child: Text(s['cancel']!, style: TextStyle(color: fg)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () =>
                        widget.onApplyColor(current, widget.isText),
                    child: Text(s['confirm']!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ],
      ),
    );
  }

  String get _hex {
    final value = _hsv.toColor().toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
