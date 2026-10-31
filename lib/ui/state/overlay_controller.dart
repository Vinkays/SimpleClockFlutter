part of '../clock_page.dart';

/// 覆盖面板（右键菜单 + 各设置面板）的开关与操作。
mixin OverlayMixin on WindowResizeMixin, ModalMixin, ToastMixin {
  /// 覆盖面板所需的最小窗口尺寸（当前窗口小于此值时临时撑大，关闭后恢复）。
  static const Size _menuMinWindow = Size(240, 300);
  static const Size _pickerMinWindow = Size(320, 440);

  bool _menuOpen = false;
  OverlayMode _overlayMode = OverlayMode.menu;
  bool _menuAutoLaunchSupported = true;
  bool _menuAutoLaunchEnabled = false;

  final AutoLaunchService _autoLaunch = AutoLaunchService();

  /// 置顶快捷键全局热键（注册/注销/Windows 冲突探测）。
  final HotkeyService _hotkeys = HotkeyService();

  /// 启动时注册置顶快捷键（默认 Ctrl+Alt+Shift+T；被占用时提示换键）。
  ///
  /// 注意：不能在 await 前读取 AppStrings.of(context)（initState 阶段禁止
  /// 依赖 inherited widget），因此失败提示放到 await 之后、mounted 防护内。
  Future<void> _initPinHotkey() async {
    final hk = widget.controller.effectivePinHotkey;
    final ok = await _hotkeys.register(hk, onTrigger: () {
      // 全局热键触发：无论窗口是否聚焦/可见都即时切换置顶
      widget.controller.toggleAlwaysOnTop();
    });
    if (!ok && mounted) {
      _showToast(
          '${AppStrings.of(context)['hotkeyConflict']!}${formatHotkey(hk)}');
    }
  }

  /// 退出前注销全局热键（释放系统热键槽位）。
  void _disposePinHotkey() {
    _hotkeys.dispose();
  }

  /// 打开「置顶快捷键」设置面板（面板较宽，需要更大的临时窗口）。
  void _switchPinHotkeyPicker() {
    setState(() => _overlayMode = OverlayMode.pinHotkey);
    _ensureWindowSize(const Size(420, 300));
  }

  /// 应用新置顶快捷键（null 恢复默认）：持久化 → 重新注册 → 结果提示。
  /// 注册冲突时返回 false，面板保持打开以便换键。
  Future<bool> _applyPinHotkey(HotKey? hotKey) async {
    final controller = widget.controller;
    final s = AppStrings.of(context);
    controller.setPinHotkey(hotKey);
    final hk = controller.effectivePinHotkey;
    final ok = await _hotkeys.register(hk, onTrigger: () {
      controller.toggleAlwaysOnTop();
    });
    if (!mounted) return ok;
    if (ok) {
      _showToast(s['hotkeyApplied']!);
      await _closeOverlay();
    } else {
      _showToast('${s['hotkeyConflict']!}${formatHotkey(hk)}');
    }
    return ok;
  }

  /// 首次启动默认开启开机自启动。
  ///
  /// 仅当从未初始化过时调用一次 [AutoLaunchService.enable]；
  /// 成功后写入标记，之后用户在菜单中手动移除/重新开启的选择都会被尊重，
  /// 不会每次启动都强制重置。
  Future<void> _initAutoStartDefault() async {
    if (widget.controller.store.isAutoStartInitialized) return;
    try {
      final ok = await _autoLaunch.enable();
      if (ok) {
        await widget.controller.store.setAutoStartInitialized(true);
      }
    } catch (_) {
      // 平台不支持或系统限制：保持静默，下次启动再尝试
    }
  }

  Future<void> _openMenu(Offset pos) async {
    // 更新弹窗（模态）显示期间不允许打开菜单/面板
    if (_updatePromptVisible || _updateProgressVisible) return;
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

  void _switchTimeFormatPicker() {
    setState(() => _overlayMode = OverlayMode.timeFormat);
    _ensureWindowSize(_menuMinWindow);
  }

  void _switchRemindIntervalPicker() {
    setState(() => _overlayMode = OverlayMode.remindInterval);
    _ensureWindowSize(_menuMinWindow);
  }

  void _switchAbout() {
    setState(() => _overlayMode = OverlayMode.about);
    _ensureWindowSize(_menuMinWindow);
  }

  void _backToMenu() {
    setState(() => _overlayMode = OverlayMode.menu);
  }

  void _applyFont(String? family) {
    widget.controller.setTextFontFamily(family);
    _closeOverlay();
  }

  /// 关闭覆盖面板：清菜单状态并恢复被撑大的窗口。
  /// 更新弹窗显示期间保持窗口撑大与弹窗可见（失焦等场景不得恢复/关闭）。
  Future<void> _closeOverlay() async {
    if (_updatePromptVisible || _updateProgressVisible) return;
    if (!_menuOpen && !_windowExpanded) return;
    if (mounted) setState(() => _menuOpen = false);
    await _restoreWindowSize();
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

  /// 切换调试日志开关（保持菜单打开，trailing 状态即时反馈）。
  void _toggleDebugLog() {
    widget.controller.setDebugLogEnabled(!widget.controller.debugLogEnabled);
  }

  /// 用系统默认编辑器打开日志文件（外部窗口，不占用工具窗）。
  Future<void> _openLogFile() async {
    final s = AppStrings.of(context);
    final file = await LogService.instance.logFile();
    if (file == null) {
      _showToast(s['noLogFile']!);
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.start('notepad', [file.path], runInShell: false);
      } else if (Platform.isMacOS) {
        await Process.start('open', [file.path], runInShell: false);
      } else {
        await Process.start('xdg-open', [file.path], runInShell: false);
      }
    } catch (e) {
      _showToast('${s['noLogFile']!} ($e)');
    }
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
}
