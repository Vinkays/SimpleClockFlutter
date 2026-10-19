/// 更新器与发布配置。
///
/// 发布新版本时，需要同步修改以下三处版本号：
/// 1. pubspec.yaml 的 `version:`
/// 2. 本文件的 [currentVersion]
/// 3. packaging/windows/simple_clock.iss 的 `MyAppVersion`
class UpdateConfig {
  UpdateConfig._();

  /// GitHub 仓库所有者。
  static const String owner = 'Vinkays';

  /// GitHub 仓库名。
  static const String repo = 'SimpleClockFlutter';

  /// 版本信息文件地址（raw.githubusercontent.com：CDN 直连、无 API 限流）。
  /// 内容由 CI 在发布新版本时自动更新（.github/workflows/release.yml 的
  /// update-latest-json job）。格式：
  /// { "version": "0.0.2", "assets": { "windows": "...", "macos": "...", "linux": "..." } }
  static const String latestInfoUrl =
      'https://raw.githubusercontent.com/Vinkays/SimpleClockFlutter/main/latest.json';

  /// 当前应用版本（与 pubspec.yaml 的 version 保持一致）。
  static const String currentVersion = '0.0.1';
}
