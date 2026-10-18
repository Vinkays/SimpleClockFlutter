import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// 开机自启动服务（三平台封装）。
///
/// - Windows：写入 HKCU\...\CurrentVersion\Run 注册表（与原版一致）
/// - macOS：通过 LaunchServices / SMAppService 登录项
/// - Linux：写入 ~/.config/autostart/*.desktop（与原版一致）
class AutoLaunchService {
  AutoLaunchService({this.appName = 'SimpleClock'});

  final String appName;
  bool _setupDone = false;

  void _ensureSetup() {
    if (_setupDone) return;
    _setupDone = true;
    try {
      LaunchAtStartup.instance.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );
    } catch (_) {
      // setup 失败不致命，后续调用仍会尝试
    }
  }

  Future<bool> isEnabled() async {
    _ensureSetup();
    return LaunchAtStartup.instance.isEnabled();
  }

  Future<bool> enable() async {
    _ensureSetup();
    return LaunchAtStartup.instance.enable();
  }

  Future<bool> disable() async {
    _ensureSetup();
    return LaunchAtStartup.instance.disable();
  }
}
