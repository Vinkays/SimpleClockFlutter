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
import '../services/update_config.dart';
import '../services/update_service.dart';
import 'overlay_panel.dart';

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

class _ClockPageState extends State<ClockPage> with WindowListener {
  static const double _resizeEdgeThreshold = 4;

  /// 覆盖面板所需的最小窗口尺寸（当前窗口小于此值时临时撑大，关闭后恢复）。
  static const Size _menuMinWindow = Size(240, 300);
  static const Size _pickerMinWindow = Size(320, 440);
  // Toast 显示时窗口太小会放不下文字，临时撑大到能完整展示
  static const Size _toastMinWindow = Size(240, 60);

  Timer? _timer;
  Timer? _toastTimer;
  Timer? _updateCheckTimer;
  String _hour = '00';
  String _minute = '00';
  String _second = '00';

  // ---- 手动拖拽状态 ----
  bool _dragging = false;
  bool _sizeLocked = false;
  bool _dragBusy = false;
  Offset? _dragAnchorPointer;
  Offset _dragCurrentWindow = Offset.zero;

  // ---- 覆盖面板状态 ----
  bool _menuOpen = false;
  OverlayMode _overlayMode = OverlayMode.menu;
  bool _menuAutoLaunchSupported = true;
  bool _menuAutoLaunchEnabled = false;
  Size? _sizeBeforeOverlay;
  bool _windowExpanded = false;
  bool _resizingWindow = false;

  // ---- 更新弹窗状态（自绘，不依赖系统 Dialog）----
  bool _updatePromptVisible = false;
  ReleaseInfo? _pendingUpdate;
  bool _updateProgressVisible = false;
  double _updateProgress = 0;

  // ---- 轻提示（替代系统通知）----
  String? _toast;

  final AutoLaunchService _autoLaunch = AutoLaunchService();
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateTime();
    // 对齐到下一个整秒再开始周期更新：
    // 避免首帧渲染耗时（尤其 debug 模式）导致 tick 相位漂移，
    // 让每次更新都落在系统秒边界附近，显示的秒始终是真实当前秒。
    final now = DateTime.now();
    final msToNextSecond = 1000 - now.millisecond;
    _timer = Timer(Duration(milliseconds: msToNextSecond), () {
      _updateTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    });
    // 启动数秒后再检查更新，避免打扰首次使用
    _updateCheckTimer = Timer(
      const Duration(seconds: 4),
      _checkForUpdates,
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _timer?.cancel();
    _toastTimer?.cancel();
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (h != _hour || m != _minute || s != _second) {
      setState(() {
        _hour = h;
        _minute = m;
        _second = s;
      });
    }
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

  // ================= 指针事件：拖拽 / 缩放 / 右键菜单 =================

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (_menuOpen) return; // 覆盖面板自身处理所有指针交互
    if (event.buttons == kSecondaryMouseButton) {
      _openMenu(event.position);
      return;
    }
    if (event.buttons != kPrimaryMouseButton) return;
    if (widget.controller.isLocked) return;
    if (_isNearEdge(event.position)) return; // 边缘交给系统缩放
    _beginDrag(event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragging) return;
    _onDragMove(event);
  }

  void _onPointerUp(PointerUpEvent event) {
    _endDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _endDrag();
  }

  bool _isNearEdge(Offset pos) {
    final size = MediaQuery.sizeOf(context);
    return pos.dx <= _resizeEdgeThreshold ||
        pos.dx >= size.width - _resizeEdgeThreshold ||
        pos.dy <= _resizeEdgeThreshold ||
        pos.dy >= size.height - _resizeEdgeThreshold;
  }

  // ---- 手动拖拽（与原版 beginMove/endMove 思路一致）----

  Future<void> _beginDrag(Offset localPos) async {
    if (_sizeLocked) return;
    Offset pos;
    Size size;
    try {
      pos = await windowManager.getPosition();
      size = await windowManager.getSize();
      // 拖动期间锁定窗口大小，避免系统在移动时触发 resize
      await windowManager.setMinimumSize(size);
      await windowManager.setMaximumSize(size);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _dragging = true;
      _sizeLocked = true;
      _dragAnchorPointer = localPos;
      _dragCurrentWindow = pos;
    });
  }

  Future<void> _onDragMove(PointerMoveEvent event) async {
    final anchor = _dragAnchorPointer;
    if (anchor == null || _dragBusy) return;
    _dragBusy = true;
    try {
      final target = _dragCurrentWindow + (event.position - anchor);
      _dragCurrentWindow = target;
      await windowManager.setPosition(target);
    } catch (_) {
    } finally {
      _dragBusy = false;
    }
  }

  Future<void> _endDrag() async {
    if (!_dragging) return;
    _dragging = false;
    if (_sizeLocked) {
      _sizeLocked = false;
      try {
        await windowManager.setMinimumSize(AppController.kMinWindowSize);
        await windowManager.setMaximumSize(AppController.kMaxWindowSize);
      } catch (_) {}
    }
    widget.controller.persistWindowState();
  }

  // ================= 覆盖面板（菜单 / 选色） =================

  Future<void> _openMenu(Offset pos) async {
    var supported = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    var enabled = false;
    if (supported) {
      try {
        enabled = await _autoLaunch.isEnabled();
      } catch (_) {
        supported = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _menuOpen = true;
      _overlayMode = OverlayMode.menu;
      _menuAutoLaunchSupported = supported;
      _menuAutoLaunchEnabled = enabled;
    });
    await _ensureWindowSize(_menuMinWindow);
  }

  void _switchPicker(bool isText) {
    setState(() {
      _overlayMode = isText ? OverlayMode.pickingText : OverlayMode.pickingBg;
    });
    _ensureWindowSize(_pickerMinWindow);
  }

  void _switchFontPicker() {
    setState(() => _overlayMode = OverlayMode.pickingFont);
    _ensureWindowSize(_menuMinWindow);
  }

  void _switchLanguagePicker() {
    setState(() => _overlayMode = OverlayMode.pickingLang);
    _ensureWindowSize(_menuMinWindow);
  }

  void _backToMenu() {
    setState(() => _overlayMode = OverlayMode.menu);
  }

  void _applyFont(String? family) {
    widget.controller.setTextFontFamily(family);
    _closeOverlay();
  }

  /// 当前窗口小于 [needed] 时临时撑大窗口（记录原始尺寸，供关闭时恢复）。
  Future<void> _ensureWindowSize(Size needed) async {
    if (_resizingWindow) return;
    _resizingWindow = true;
    try {
      final cur = await windowManager.getSize();
      if (cur.width < needed.width || cur.height < needed.height) {
        _sizeBeforeOverlay ??= cur;
        _windowExpanded = true;
        final target = Size(
          math.max(cur.width, needed.width),
          math.max(cur.height, needed.height),
        );
        await windowManager.setSize(target);
      }
    } catch (_) {
      // 窗口未就绪等情况下静默忽略，面板本身仍可滚动使用
    } finally {
      _resizingWindow = false;
    }
  }

  Future<void> _closeOverlay() async {
    // 更新弹窗显示期间保持窗口撑大与弹窗可见（失焦等场景不得恢复/关闭）
    if (_updatePromptVisible || _updateProgressVisible) return;
    if (!_menuOpen && !_windowExpanded) return;
    if (mounted) setState(() => _menuOpen = false);
    if (_windowExpanded) {
      _windowExpanded = false;
      final restore = _sizeBeforeOverlay;
      _sizeBeforeOverlay = null;
      if (restore != null) {
        try {
          await windowManager.setSize(restore);
        } catch (_) {}
      }
    }
  }

  void _applyColor(Color color, bool isText) {
    final controller = widget.controller;
    controller.setAppearance(
      isText ? controller.bgColor : color,
      isText ? color : controller.textColor,
    );
    _closeOverlay();
  }

  void _toggleLock() {
    widget.controller.toggleLock();
    _closeOverlay();
  }

  void _toggleAlwaysOnTop() {
    widget.controller.toggleAlwaysOnTop();
    _closeOverlay();
  }

  Future<void> _toggleAutoLaunch() async {
    final target = !_menuAutoLaunchEnabled;
    _closeOverlay();
    final s = AppStrings.of(context);
    try {
      final ok = target ? await _autoLaunch.enable() : await _autoLaunch.disable();
      _showToast(
        ok
            ? (target ? s['autoStartSuccess']! : s['autoStartRemoveSuccess']!)
            : s['autoStartFailed']!,
      );
    } catch (e) {
      _showToast('${s['autoStartFailedDetail']!}$e');
    }
  }

  Future<void> _quitApp() async {
    await _closeOverlay(); // 先恢复窗口尺寸，再持久化并退出
    widget.controller.quitApp();
  }

  // ---- 轻提示 ----

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    // 窗口太小时临时撑大，保证 Toast 文字完整可见
    _ensureWindowSize(_toastMinWindow);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _toast = null);
        // 恢复被撑大的窗口尺寸
        _closeOverlay();
      }
    });
  }

  // ---- 自动更新 ----

  /// 启动后延迟调用：检查 GitHub Releases，发现新版本弹窗提示。
  Future<void> _checkForUpdates() async {
    final info = await _updateService.checkForUpdate();
    if (info == null || !mounted) return;
    await _ensureWindowSize(const Size(400, 320));
    if (!mounted) return;
    setState(() {
      _pendingUpdate = info;
      _updatePromptVisible = true;
    });
  }

  /// 「稍后更新」：关闭提示并恢复被撑大的窗口。
  void _updateLater() {
    if (!mounted) return;
    setState(() => _updatePromptVisible = false);
    _closeOverlay();
  }

  /// 「立即更新」：关闭提示 → 下载安装包（期间保持窗口撑大，避免进度卡溢出）
  /// → 启动安装器后退出应用。
  Future<void> _updateNow() async {
    if (!mounted) return;
    // 提示关闭，但窗口保持撑大状态（供下载进度卡使用，结束后再恢复）
    setState(() => _updatePromptVisible = false);
    final info = _pendingUpdate;
    if (info == null) return;
    final s = AppStrings.of(context);

    // 优先找 Windows 安装包；其它平台也可用通用下载
    final asset = info.assetFor({'.exe'});
    if (asset == null) {
      await _closeOverlay();
      _showToast(s['updateFailed']!);
      return;
    }

    // 下载并显示进度（自绘，不依赖系统 Dialog）
    setState(() {
      _updateProgressVisible = true;
      _updateProgress = 0;
    });
    File? installer;
    try {
      installer = await _updateService.downloadAsset(
        asset,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _updateProgress = p);
        },
      );
    } finally {
      if (mounted) setState(() => _updateProgressVisible = false);
    }
    if (!mounted) return;
    if (installer == null) {
      await _closeOverlay();
      _showToast(s['updateFailed']!);
      return;
    }

    // 启动安装器后退出应用（launchInstaller 只启动不等待；即将退出无需恢复窗口）
    _showToast(s['updateLaunching']!);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final ok = await _updateService.launchInstaller(installer);
    if (ok && mounted) {
      widget.controller.quitApp();
    } else if (mounted) {
      await _closeOverlay();
      _showToast(s['updateFailed']!);
    }
  }

  /// 更新提示卡片（自绘：绕开系统 Dialog 在工具窗/失焦/缩放下的渲染异常）。
  Widget _buildUpdatePromptCard() {
    final s = AppStrings.of(context);
    final info = _pendingUpdate;
    if (info == null) return const SizedBox.shrink();
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s['updateAvailableTitle']!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            s['updateAvailableBody']!
                .replaceFirst('{0}', UpdateConfig.currentVersion)
                .replaceFirst('{1}', info.tagName),
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _updateLater,
                child: Text(s['updateLater']!),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _updateNow,
                child: Text(s['updateNow']!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 更新下载进度卡片（自绘）。
  Widget _buildUpdateProgressCard() {
    final s = AppStrings.of(context);
    final percent = (_updateProgress.clamp(0.0, 1.0) * 100).round();
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s['updateDownloading']!.replaceFirst('{0}', '$percent'),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _updateProgress.clamp(0.0, 1.0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _updateProgressVisible = false),
                child: Text(s['updateLater']!),
              ),
            ],
          ),
        ],
      ),
    );
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
                  _ScaledClock(
                    hour: _hour,
                    minute: _minute,
                    second: _second,
                    textColor: widget.controller.textColor,
                    textFontFamily: widget.controller.textFontFamily,
                  ),
                  if (_updatePromptVisible)
                    Positioned.fill(
                      child: Stack(
                        children: [
                          // 遮罩：点击不关闭（barrierDismissible 等价于 false）
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                          ),
                          Center(child: _buildUpdatePromptCard()),
                        ],
                      ),
                    ),
                  if (_updateProgressVisible)
                    Positioned.fill(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                          ),
                          Center(child: _buildUpdateProgressCard()),
                        ],
                      ),
                    ),
                  if (_menuOpen)
                    Positioned.fill(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 半透明遮罩：点击空白处关闭面板
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _closeOverlay,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                          OverlayPanel(
                            controller: widget.controller,
                            mode: _overlayMode,
                            autoLaunchSupported: _menuAutoLaunchSupported,
                            autoLaunchEnabled: _menuAutoLaunchEnabled,
                            onPickTextColor: () => _switchPicker(true),
                            onPickBgColor: () => _switchPicker(false),
                            onPickFont: _switchFontPicker,
                            onPickLanguage: _switchLanguagePicker,
                            onToggleLock: _toggleLock,
                            onToggleTop: _toggleAlwaysOnTop,
                            onToggleAutoLaunch: _toggleAutoLaunch,
                            onQuit: _quitApp,
                            onBackToMenu: _backToMenu,
                            onApplyColor: _applyColor,
                            onApplyFont: _applyFont,
                          ),
                        ],
                      ),
                    ),
                  if (_toast != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}

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
class _ScaledClock extends StatelessWidget {
  const _ScaledClock({
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
      painter: _ClockTextPainter(
        text: '$hour:$minute:$second',
        style: textStyle,
      ),
      size: Size.infinite,
    );
  }
}

/// 时钟文本的绘制器：测量文本后按窗口尺寸拉伸绘制。
class _ClockTextPainter extends CustomPainter {
  _ClockTextPainter({required this.text, required this.style});

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
  bool shouldRepaint(_ClockTextPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.style != style;
}
