import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// 系统托盘服务：工具栏窗口模式的配套入口。
///
/// 窗口不出现在任务栏后，用户只能通过托盘找回窗口 / 退出应用。
/// 初始化失败（如 Linux 无托盘环境）时保持 [isActive]=false，
/// 上层回退为"关闭窗口 = 退出应用"的普通行为。
class TrayService with TrayListener {
  TrayService._();

  static final TrayService instance = TrayService._();

  bool _active = false;

  /// 托盘是否已成功挂载。
  bool get isActive => _active;

  void Function()? _onShow;
  void Function()? _onQuit;

  /// 初始化托盘：设图标 → 挂监听 → 设提示 → 设菜单。
  Future<void> init({
    required void Function() onShow,
    required void Function() onQuit,
    String? tooltip,
    List<MenuItem>? menu,
  }) async {
    _onShow = onShow;
    _onQuit = onQuit;
    try {
      // Windows 的 LoadImage 仅支持 .ico（PNG 会加载失败显示空白图标）；
      // macOS/Linux 走 PNG。
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );
      trayManager.addListener(this);
      if (tooltip != null) await trayManager.setToolTip(tooltip);
      if (menu != null && menu.isNotEmpty) {
        await trayManager.setContextMenu(Menu(items: menu));
      }
      _active = true;
    } catch (_) {
      _active = false;
    }
  }

  /// 销毁托盘（退出应用前调用）。
  Future<void> destroy() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    _active = false;
  }

  // 单击 / 双击托盘图标：恢复窗口
  @override
  void onTrayIconMouseDown() => _onShow?.call();

  @override
  void onTrayIconMouseUp() => _onShow?.call();

  // 右键托盘图标：显式弹出菜单（Windows 原生实现不会自动弹出）
  @override
  void onTrayIconRightMouseDown() {
    try {
      trayManager.popUpContextMenu();
    } catch (_) {}
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _onShow?.call();
        break;
      case 'quit':
        _onQuit?.call();
        break;
    }
  }
}
