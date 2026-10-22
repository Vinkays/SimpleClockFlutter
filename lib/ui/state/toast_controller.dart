part of '../clock_page.dart';

/// 轻提示（替代系统通知）：窗口太小时临时撑大；2 秒后消失并恢复窗口。
mixin ToastMixin on WindowResizeMixin {
  // Toast 显示时窗口太小会放不下文字，临时撑大到能完整展示
  static const Size _toastMinWindow = Size(240, 60);

  String? _toast;
  Timer? _toastTimer;

  /// Toast 结束时恢复窗口：菜单仍打开则保持撑大，菜单关闭时统一恢复。
  /// 组合逻辑（需 Overlay 状态）由 [_ClockPageState] 实现。
  Future<void> _restoreAfterToast();

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _ensureWindowSize(_toastMinWindow);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _toast = null);
        _restoreAfterToast();
      }
    });
  }

  void _disposeToast() => _toastTimer?.cancel();
}
