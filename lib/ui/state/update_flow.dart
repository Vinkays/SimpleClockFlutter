part of '../clock_page.dart';

/// 自动更新：检查（心跳 + 退避重试）、冷却去重、弹窗与下载流程。
mixin UpdateFlowMixin on OverlayMixin, ModalMixin, WindowResizeMixin, ToastMixin {
  /// 心跳间隔：应用常驻托盘，每小时复查一次更新。
  static const Duration _updateHeartbeat = Duration(hours: 1);
  /// 网络失败退避间隔：3min → 15min → 30min，之后并轨心跳。
  static const List<Duration> _retryBackoff = [
    Duration(minutes: 3),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  Timer? _updateCheckTimer;
  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// 本次检查是否由用户手动触发（「检查更新」按钮）。
  /// 手动检查要给结果反馈（已是最新版 / 检查失败），自动检查保持静默。
  bool _manualCheck = false;

  final UpdateService _updateService = UpdateService();

  /// 启动更新检查调度（initState 调用一次）：
  /// 启动 4 秒后首次检查，之后每小时心跳兜底。
  void _startUpdateSchedule() {
    LogService.instance.info('update.schedule start (heartbeat 1h)');
    _updateCheckTimer = Timer(
      const Duration(seconds: 4),
      _checkForUpdates,
    );
    _heartbeatTimer = Timer.periodic(
      _updateHeartbeat,
      (_) => _checkForUpdates(),
    );
  }

  /// 手动检查更新（「关于我们」面板按钮）：
  /// 清除冷却记录后立即触发检查，便于本地测试 / 用户主动想看。
  Future<void> _checkUpdatesNow() async {
    LogService.instance.info('update.check manual (cooldown cleared)');
    await widget.controller.store.clearUpdateSnooze();
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _manualCheck = true;
    await _checkForUpdates();
  }

  /// 启动后延迟调用 / 心跳触发：检查 GitHub Releases，发现新版本弹窗提示。
  ///
  /// 状态处理：
  /// - 有新版本：先过冷却去重（同一版本在提醒间隔内不重复提示），再弹窗；
  /// - 网络不可达 / 服务端 5xx：按 3/15/30 分钟退避重试，耗尽后并轨心跳；
  /// - 4xx / 内容非法：重试无意义，静默忽略。
  Future<void> _checkForUpdates() async {
    LogService.instance.info('update.check trigger (retryAttempt=$_retryAttempt)');
    final result = await _updateService.checkForUpdate();
    if (!mounted) return;
    final s = AppStrings.of(context);
    // 取手动标记并复位：只对本次检查生效
    final manual = _manualCheck;
    _manualCheck = false;
    switch (result.state) {
      case UpdateCheckState.updateAvailable:
        _retryAttempt = 0;
        final info = result.info;
        if (info == null) return;
        // 冷却去重：点过「稍后」/取消过下载的版本，在提醒间隔内不再打扰
        final snoozeVersion = widget.controller.store.updateSnoozeVersion;
        final snoozeUntil = widget.controller.store.updateSnoozeUntil;
        if (snoozeVersion == info.tagName &&
            snoozeUntil != null &&
            DateTime.now().millisecondsSinceEpoch < snoozeUntil) {
          LogService.instance.info(
            'update.check snoozed tag=${info.tagName} '
            'until=${DateTime.fromMillisecondsSinceEpoch(snoozeUntil).toIso8601String()}',
          );
          // 手动检查前已清冷却，正常不会走到此分支；静默处理
          return;
        }
        LogService.instance.info(
          'update.check show-prompt tag=${info.tagName}',
        );
        // 不主动关闭菜单：更新弹窗渲染在菜单之上，先处理弹窗，菜单保持可用
        await _ensureWindowSize(const Size(400, 320));
        if (!mounted) return;
        setState(() {
          _pendingUpdate = info;
          _updatePromptVisible = true;
        });
      case UpdateCheckState.upToDate:
        LogService.instance.info('update.check up-to-date');
        _retryAttempt = 0;
        if (manual) _showToast(s['updateUpToDate']!);
        return;
      case UpdateCheckState.httpError:
        LogService.instance.info('update.check http-error (no retry)');
        _retryAttempt = 0;
        if (manual) _showToast(s['updateCheckFailed']!);
        return;
      case UpdateCheckState.notConfigured:
        LogService.instance.info('update.check not-configured');
        _retryAttempt = 0;
        if (manual) _showToast(s['updateCheckFailed']!);
        return;
      case UpdateCheckState.networkError:
      case UpdateCheckState.serverError:
        if (manual) _showToast(s['updateCheckRetry']!);
        _scheduleRetry();
        return;
    }
  }

  /// 网络失败退避重试：3min → 15min → 30min，耗尽后由每小时心跳接管。
  void _scheduleRetry() {
    if (_retryAttempt >= _retryBackoff.length) return;
    final delay = _retryBackoff[_retryAttempt];
    _retryAttempt++;
    _retryTimer?.cancel();
    LogService.instance.info(
      'update.check retry-scheduled attempt=$_retryAttempt '
      'delay=${delay.inMinutes}min',
    );
    _retryTimer = Timer(delay, _checkForUpdates);
  }

  /// 记录「稍后」冷却：当前待更新版本在提醒间隔内不再提示。
  void _applyUpdateSnooze() {
    final info = _pendingUpdate;
    if (info == null) return;
    final hours = widget.controller.updateRemindHours;
    final until = DateTime.now().add(Duration(hours: hours));
    LogService.instance.info(
      'update.snooze tag=${info.tagName} hours=$hours '
      'until=${until.toIso8601String()}',
    );
    widget.controller.store.setUpdateSnooze(
      info.tagName,
      until.millisecondsSinceEpoch,
    );
  }

  /// 「稍后更新」：关闭提示层并进入冷却；菜单仍打开时保持窗口与菜单（共享撑大状态）。
  void _updateLater() {
    LogService.instance.info('update.later clicked');
    _applyUpdateSnooze();
    _closeUpdateLayer();
  }

  /// 关闭更新弹窗层：清提示+进度状态；菜单未打开时恢复被撑大的窗口。
  void _closeUpdateLayer() {
    if (!mounted) return;
    setState(() {
      _updatePromptVisible = false;
      _updateProgressVisible = false;
    });
    // 菜单还开着则保持窗口撑大（菜单面板需要），待菜单关闭时再统一恢复
    if (!_menuOpen) _closeOverlay();
  }

  /// 取消下载：标记取消并关闭进度层（等同「稍后」进入冷却，菜单打开时保持窗口与菜单）。
  void _cancelDownload() {
    LogService.instance.info('update.download cancelled by user');
    _updateCancelled = true;
    _applyUpdateSnooze();
    _closeUpdateLayer();
  }

  /// 「立即更新」：关闭提示 → 下载安装包（期间保持窗口撑大，避免进度卡溢出）
  /// → 启动安装器后退出应用。
  Future<void> _updateNow() async {
    if (!mounted) return;
    LogService.instance.info(
      'update.now clicked tag=${_pendingUpdate?.tagName ?? '-'}',
    );
    // 提示关闭，但窗口保持撑大状态（供下载进度卡使用，结束后再恢复）
    setState(() => _updatePromptVisible = false);
    final info = _pendingUpdate;
    if (info == null) return;
    final s = AppStrings.of(context);

    // 按当前平台选择安装包（Windows .exe / macOS .dmg / Linux .AppImage）
    final asset = _updateService.platformAsset(info);
    if (asset == null) {
      if (!_menuOpen) await _closeOverlay();
      _showToast(s['updateFailed']!);
      return;
    }

    // 下载并显示进度（自绘，不依赖系统 Dialog）
    setState(() {
      _updateProgressVisible = true;
      _updateProgress = 0;
      _updateCancelled = false;
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
    // 用户已取消：丢弃下载结果，不安装不提示
    if (_updateCancelled) return;
    if (installer == null) {
      LogService.instance.info('update.download result null');
      if (!_menuOpen) await _closeOverlay();
      _showToast(s['updateFailed']!);
      return;
    }

    // 启动安装器后退出应用（launchInstaller 只启动不等待；即将退出无需恢复窗口）
    _showToast(s['updateLaunching']!);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final ok = await _updateService.launchInstaller(installer);
    LogService.instance.info('update.launch result ok=$ok');
    if (ok && mounted) {
      widget.controller.quitApp();
    } else if (mounted) {
      if (!_menuOpen) await _closeOverlay();
      _showToast(s['updateFailed']!);
    }
  }

  void _disposeUpdateSchedule() {
    _updateCheckTimer?.cancel();
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    LogService.instance.info('update.schedule disposed');
  }
}
