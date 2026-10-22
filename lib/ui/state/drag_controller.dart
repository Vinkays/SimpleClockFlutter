part of '../clock_page.dart';

/// 左键拖拽窗口（拖动期间锁定尺寸，防止 resize 抖动）。
mixin ClockDragMixin on OverlayMixin {
  static const double _resizeEdgeThreshold = 4;

  bool _dragging = false;
  bool _sizeLocked = false;
  bool _dragBusy = false;
  Offset? _dragAnchorPointer;
  Offset _dragCurrentWindow = Offset.zero;

  bool _isNearEdge(Offset pos) {
    final size = MediaQuery.sizeOf(context);
    return pos.dx <= _resizeEdgeThreshold ||
        pos.dx >= size.width - _resizeEdgeThreshold ||
        pos.dy <= _resizeEdgeThreshold ||
        pos.dy >= size.height - _resizeEdgeThreshold;
  }

  // ---- 指针事件分发：拖拽 / 缩放 / 右键菜单 ----

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

  // 手动拖拽（与原版 beginMove/endMove 思路一致）

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
}
