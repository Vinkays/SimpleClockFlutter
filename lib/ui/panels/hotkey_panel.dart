import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../controllers/app_controller.dart';
import '../../services/app_strings.dart';
import '../../services/hotkey_service.dart';
import '../widgets/modal_shell.dart';
import 'lang_panel.dart' show PanelHeader;

/// 置顶快捷键设置面板：自包含模态外壳（[ModalShell]）。
///
/// 改键采用两段式：录制新组合后不立即生效，进入「待确认」态——
/// Enter 确认启用（注册全局热键并持久化），Esc 取消，继续按键可替换候选。
/// 约束不变：至少一个修饰键；普通键除 Enter 外；Esc 保留为取消。
class HotkeyPanel extends StatefulWidget {
  const HotkeyPanel({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onApply,
    required this.onShowToast,
    required this.onTapOutside,
  });

  final AppController controller;
  final VoidCallback onBack;

  /// 应用新快捷键（null 恢复默认）；返回是否注册成功。
  /// 成功时由外部负责关闭面板。
  final Future<bool> Function(HotKey? hotKey) onApply;

  /// 校验失败等轻提示。
  final void Function(String message) onShowToast;

  /// 遮罩点击（关闭整个菜单层）。
  final VoidCallback onTapOutside;

  @override
  State<HotkeyPanel> createState() => _HotkeyPanelState();
}

class _HotkeyPanelState extends State<HotkeyPanel> {
  /// 是否处于录制流程（等待组合或待确认）。
  bool _recording = false;

  /// 已捕获待确认的组合（null = 仍在等待按下组合键）。
  HotKey? _candidate;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _candidate = null;
    });
    // 面板打开时窗口已撑大并聚焦，录制框再主动抢一次焦点接收按键
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelRecording() {
    setState(() {
      _recording = false;
      _candidate = null;
    });
  }

  /// 确认启用候选组合：交给外部注册并持久化。
  /// 注册失败（冲突）时外部 Toast 提示，这里回到初始状态。
  Future<void> _applyCandidate() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final ok = await widget.onApply(candidate);
    if (!mounted) return;
    if (!ok) {
      // 冲突未生效：回到初始态，避免"看着是新键其实没生效"
      _cancelRecording();
    }
  }

  /// 捕获组合键：修饰键按下时继续等待普通键；
  /// 普通键到来时按当前按住的修饰键构造候选并进入「待确认」态。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final s = AppStrings.of(context);
    final key = event.physicalKey;

    // Esc 取消录制（保留，不作为可录制普通键）
    if (key == PhysicalKeyboardKey.escape) {
      _cancelRecording();
      return KeyEventResult.handled;
    }

    // 修饰键本身不构成"普通键"，继续等待
    final isModifierKey =
        HotKeyModifier.values.any((m) => m.physicalKeys.contains(key));
    if (isModifierKey) return KeyEventResult.handled;

    // Enter 作为确认键：有待确认候选时启用，否则忽略
    if (key == PhysicalKeyboardKey.enter) {
      if (_candidate != null) _applyCandidate();
      return KeyEventResult.handled;
    }

    // 至少一个修饰键（用真实按住状态汇总，兼容先按修饰键再按普通键）
    final pressedMods = HotKeyModifier.values
        .where((m) => m.isModifierPressed)
        .toList();
    if (pressedMods.isEmpty) {
      widget.onShowToast(s['hotkeyNeedModifier']!);
      return KeyEventResult.handled;
    }

    final current = widget.controller.effectivePinHotkey;
    final candidate = HotKey(
      key: key,
      modifiers: pressedMods,
      scope: HotKeyScope.system,
    );
    // 与当前键位相同：提示并留在录制态，等待按下新组合
    if (candidate.physicalKey == current.physicalKey &&
        _sameModifiers(pressedMods, current.modifiers)) {
      widget.onShowToast(s['hotkeySame']!);
      return KeyEventResult.handled;
    }

    // 捕获成功：进入待确认态（不立即生效）
    setState(() => _candidate = candidate);
    return KeyEventResult.handled;
  }

  static bool _sameModifiers(
    List<HotKeyModifier> a,
    List<HotKeyModifier>? b,
  ) {
    if (a.length != (b?.length ?? 0)) return false;
    return a.every((m) => b!.contains(m));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final fg = widget.controller.textColor;
    final bg = widget.controller.bgColor;
    return ModalShell(
      width: 400,
      fg: fg,
      bg: bg,
      textFontFamily: widget.controller.textFontFamily,
      onTapOutside: widget.onTapOutside,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: s['hotkeyTitle']!, fg: fg, onBack: widget.onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  // 录制状态下顺带显示修改前的键位，方便对照
                  _recording
                      ? '${s['hotkeyCurrent']!}  ${formatHotkey(widget.controller.effectivePinHotkey)}'
                      : s['hotkeyCurrent']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),
                Focus(
                  focusNode: _focusNode,
                  autofocus: false,
                  onKeyEvent: _recording ? _onKeyEvent : null,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _recording
                            ? fg
                            : fg.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: _recording
                          ? Color.lerp(bg, const Color(0xFF2196F3), 0.08)
                          : null,
                    ),
                    child: Text(
                      _candidate != null
                          ? formatHotkey(_candidate!)
                          : _recording
                              ? s['hotkeyRecording']!
                              : formatHotkey(
                                  widget.controller.effectivePinHotkey),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _recording
                            ? fg.withValues(alpha: 0.8)
                            : fg,
                      ),
                    ),
                  ),
                ),
                if (_candidate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    s['hotkeyConfirmHint']!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        // 待确认：确认使用；录制中：取消；空闲：开始录制
                        onPressed: _candidate != null
                            ? _applyCandidate
                            : _recording
                                ? _cancelRecording
                                : _startRecording,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: Icon(
                          _candidate != null
                              ? Icons.check
                              : _recording
                                  ? Icons.close
                                  : Icons.keyboard,
                          size: 16,
                        ),
                        label: Text(
                          _candidate != null
                              ? s['hotkeyApplyEnter']!
                              : _recording
                                  ? s['cancelEsc']!
                                  : s['hotkeyChange']!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        // 待确认：取消；其余：恢复默认
                        onPressed: _candidate != null
                            ? _cancelRecording
                            : () => widget.onApply(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: Icon(
                          _candidate != null
                              ? Icons.close
                              : Icons.restart_alt,
                          size: 16,
                        ),
                        label: Text(
                          _candidate != null
                              ? s['cancelEsc']!
                              : s['hotkeyReset']!,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s['hotkeyDesc']!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: fg.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
