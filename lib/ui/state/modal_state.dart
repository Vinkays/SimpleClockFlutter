part of '../clock_page.dart';

/// 更新弹窗/进度层的模态状态（自绘，不依赖系统 Dialog）。
mixin ModalMixin on State<ClockPage> {
  bool _updatePromptVisible = false;
  ReleaseInfo? _pendingUpdate;
  bool _updateProgressVisible = false;
  double _updateProgress = 0;
  bool _updateCancelled = false;
}
