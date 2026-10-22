import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart'
    show kPrimaryMouseButton, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/app_controller.dart';
import '../services/app_strings.dart';
import '../services/auto_launch_service.dart';
import '../services/log_service.dart';
import '../services/update_service.dart';
import 'panels/about_panel.dart';
import 'panels/color_panel.dart';
import 'panels/font_panel.dart';
import 'panels/lang_panel.dart';
import 'panels/menu_panel.dart';
import 'panels/remind_interval_panel.dart';
import 'widgets/scaled_clock.dart';
import 'widgets/update_cards.dart';

// 按职责拆分的 State 行为 mixin（part of 同库，共享私有成员）：
//  - clock_ticker.dart      时钟走时（整秒对齐 + 每秒更新）
//  - modal_state.dart       更新弹窗/进度层模态状态
//  - window_resize.dart     窗口撑大/恢复
//  - toast_controller.dart  轻提示
//  - overlay_controller.dart 右键菜单与设置面板
//  - drag_controller.dart   左键拖拽窗口
//  - update_flow.dart       自动更新（检查/重试/冷却/下载）
part 'state/clock_ticker.dart';
part 'state/modal_state.dart';
part 'state/window_resize.dart';
part 'state/toast_controller.dart';
part 'state/overlay_controller.dart';
part 'state/drag_controller.dart';
part 'state/update_flow.dart';

/// 覆盖层模式：右键菜单 / 选色 / 字体 / 语言 / 更新提醒间隔 / 关于。
enum OverlayMode {
  menu,
  pickingText,
  pickingBg,
  pickingFont,
  pickingLang,
  remindInterval,
  about,
}

/// 时钟主界面（对应原版 src/pages/main/App.vue）。
///
/// 无边框窗口内的时钟：
/// - 时间文本始终填满整个窗口（BoxFit.fill），任意窗口比例下无左右空隙
/// - 左键拖动窗口（拖动期间锁定窗口大小，防止 resize 抖动）
/// - 边缘 4px 内不拦截鼠标，交给系统缩放窗口
/// - 右键弹出覆盖面板（菜单 / 颜色选择）；窗口过小时自动临时撑大，
///   操作完成后恢复原尺寸，保证面板内容永远完整可用
class ClockPage extends StatefulWidget {
  const ClockPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage>
    with
        ClockTickerMixin,
        ModalMixin,
        WindowResizeMixin,
        ToastMixin,
        OverlayMixin,
        ClockDragMixin,
        UpdateFlowMixin,
        WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _startClockTicker();
    _startUpdateSchedule();
    // 首次启动默认开启开机自启动（写标记后尊重用户后续选择）
    _initAutoStartDefault();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _disposeClockTicker();
    _disposeToast();
    _disposeUpdateSchedule();
    super.dispose();
  }

  /// Toast 结束时恢复窗口：菜单仍打开则保持撑大，菜单关闭时统一恢复。
  @override
  Future<void> _restoreAfterToast() async {
    if (!_menuOpen) await _closeOverlay();
  }

  // ================= WindowListener =================

  @override
  void onWindowResize() {
    // 撑大/恢复窗口期间也会触发 resize；最终一次持久化的会是恢复后的尺寸
    widget.controller.handleWindowResize();
  }

  @override
  void onWindowMoved() {
    widget.controller.handleWindowMoved();
  }

  @override
  void onWindowBlur() {
    _closeOverlay();
    _endDrag();
  }

  // ================= 构建 =================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: widget.controller.bgColor),
                  ScaledClock(
                    hour: _hour,
                    minute: _minute,
                    second: _second,
                    textColor: widget.controller.textColor,
                    textFontFamily: widget.controller.textFontFamily,
                  ),
                  if (_menuOpen)
                    Positioned.fill(
                      // 各面板自包含模态外壳（ModalShell：遮罩+卡片+滚动），
                      // 这里只负责按当前模式选择渲染哪个面板
                      child: switch (_overlayMode) {
                        OverlayMode.menu => MenuPanel(
                            controller: widget.controller,
                            autoLaunchSupported: _menuAutoLaunchSupported,
                            autoLaunchEnabled: _menuAutoLaunchEnabled,
                            onPickTextColor: () => _switchPicker(true),
                            onPickBgColor: () => _switchPicker(false),
                            onPickFont: _switchFontPicker,
                            onPickLanguage: _switchLanguagePicker,
                            onPickRemindInterval: _switchRemindIntervalPicker,
                            onAbout: _switchAbout,
                            onToggleDebugLog: _toggleDebugLog,
                            onToggleLock: _toggleLock,
                            onToggleTop: _toggleAlwaysOnTop,
                            onToggleAutoLaunch: _toggleAutoLaunch,
                            onQuit: _quitApp,
                            onClose: _closeOverlay,
                          ),
                        OverlayMode.pickingText => ColorPanel(
                            controller: widget.controller,
                            isText: true,
                            onBack: _backToMenu,
                            onApplyColor: _applyColor,
                            onTapOutside: _closeOverlay,
                          ),
                        OverlayMode.pickingBg => ColorPanel(
                            controller: widget.controller,
                            isText: false,
                            onBack: _backToMenu,
                            onApplyColor: _applyColor,
                            onTapOutside: _closeOverlay,
                          ),
                        OverlayMode.pickingFont => FontPanel(
                            controller: widget.controller,
                            onBack: _backToMenu,
                            onApplyFont: _applyFont,
                            onTapOutside: _closeOverlay,
                          ),
                        OverlayMode.pickingLang => LangPanel(
                            controller: widget.controller,
                            onBack: _backToMenu,
                            onTapOutside: _closeOverlay,
                          ),
                        OverlayMode.remindInterval => RemindIntervalPanel(
                            controller: widget.controller,
                            onBack: _backToMenu,
                            onApplyRemindInterval: (h) =>
                                widget.controller.setUpdateRemindHours(h),
                            onShowToast: _showToast,
                            onTapOutside: _closeOverlay,
                          ),
                        OverlayMode.about => AboutPanel(
                            controller: widget.controller,
                            onBack: _backToMenu,
                            onCheckUpdateNow: _checkUpdatesNow,
                            onOpenLogFile: _openLogFile,
                            onTapOutside: _closeOverlay,
                          ),
                      },
                    ),
                  // 更新弹窗渲染在菜单之上（模态）：先处理弹窗，菜单保持可用
                  if (_updatePromptVisible)
                    Positioned.fill(
                      child: UpdatePromptCard(
                        info: _pendingUpdate!,
                        onLater: _updateLater,
                        onNow: _updateNow,
                        // 遮罩点击无操作（防误触，避免误关弹窗/误入冷却）——
                        // 关闭必须明确点「稍后」或「立即更新」按钮
                        onTapOutside: () {},
                      ),
                    ),
                  if (_updateProgressVisible)
                    Positioned.fill(
                      child: UpdateProgressCard(
                        progress: _updateProgress,
                        onCancel: _cancelDownload,
                        onTapOutside: _cancelDownload,
                      ),
                    ),
                  if (_toast != null)
                    Positioned.fill(
                      child: Center(
                        // 与更新弹窗同理：裸 Container+Text 缺 Material 上下文
                        // 会触发渲染异常（双划线），必须包 Material 提供
                        // DefaultTextStyle 标准解析路径
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 280,
                              ),
                              // 窗口仍过小时文字按比例缩小，保证完整可见
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _toast!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
