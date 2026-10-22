part of '../clock_page.dart';

/// 窗口尺寸管理：面板/弹窗/toast 需要更大空间时临时撑大，结束时恢复。
mixin WindowResizeMixin on State<ClockPage> {
  Size? _sizeBeforeOverlay;
  bool _windowExpanded = false;
  bool _resizingWindow = false;

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

  /// 恢复被撑大的窗口到记录的原尺寸（无撑大记录时无操作）。
  Future<void> _restoreWindowSize() async {
    if (!_windowExpanded) return;
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
