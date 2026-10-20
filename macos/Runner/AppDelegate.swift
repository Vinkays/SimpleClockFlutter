import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    // 工具栏/常驻工具窗：移除主菜单。
    // 仅靠 LSUIElement 不够——MainMenu.xib 显式设置了 mainMenu，
    // agent 应用在窗口激活时仍会显示菜单栏（应用名/Edit/View/Window/Help）。
    // 在窗口出现前清掉，彻底不显示；退出走系统托盘。
    NSApp.mainMenu = nil
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
