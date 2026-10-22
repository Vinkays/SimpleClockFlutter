import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_service.dart';
import 'update_config.dart';

/// 更新检查结果状态。
///
/// - [networkError]/[serverError]：可退避重试（网络不可达 / 服务端 5xx）；
/// - [httpError]：内容问题（latest.json 缺失、格式非法），重试无意义，不重试。
enum UpdateCheckState {
  /// 发现新版本（[UpdateCheckResult.info] 非空）。
  updateAvailable,

  /// 已是最新版本。
  upToDate,

  /// 网络不可达（超时 / 连接失败 / DNS 解析失败）。
  networkError,

  /// 服务端返回 5xx。
  serverError,

  /// HTTP 4xx 或内容格式非法。
  httpError,

  /// 未配置 GitHub 仓库。
  notConfigured,
}

/// 一次更新检查的结果。
class UpdateCheckResult {
  const UpdateCheckResult(this.state, [this.info]);

  final UpdateCheckState state;
  final ReleaseInfo? info;

  /// 是否值得退避重试（网络层问题；内容问题重试无意义）。
  bool get retryable =>
      state == UpdateCheckState.networkError ||
      state == UpdateCheckState.serverError;
}

/// GitHub Release 中的一个资源（如安装包）。
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;
}

/// 最新版本信息。
class ReleaseInfo {
  const ReleaseInfo({required this.tagName, required this.assets});

  final String tagName;
  final List<ReleaseAsset> assets;

  /// 平台匹配的安装包资源（Windows 取 .exe；无匹配取第一个）。
  ReleaseAsset? assetFor(Set<String> suffixes) {
    for (final a in assets) {
      if (suffixes.any((s) => a.name.toLowerCase().endsWith(s))) return a;
    }
    return assets.isEmpty ? null : assets.first;
  }
}

/// 自建更新器：检查 GitHub Releases → 下载安装包 → 启动安装器。
///
/// 纯 Dart 实现（dart:io），无第三方依赖，三平台可用；
/// 安装环节按平台调用不同命令（Windows 静默跑 Inno Setup 安装包等）。
class UpdateService {
  UpdateService({
    String? owner,
    String? repo,
    String? currentVersion,
  })  : owner = owner ?? UpdateConfig.owner,
        repo = repo ?? UpdateConfig.repo,
        currentVersion = currentVersion ?? UpdateConfig.currentVersion;

  final String owner;
  final String repo;
  final String currentVersion;

  static const String _apiBase = 'https://api.github.com';

  /// 是否已配置 GitHub 仓库（未配置时不发起检查）。
  bool get configured =>
      owner.isNotEmpty &&
      !owner.startsWith('YOUR_') &&
      repo.isNotEmpty;

  /// 检查是否有新版本。
  ///
  /// 通道顺序：raw.githubusercontent.com（CDN、无 API 限流、实时）→
  /// jsdelivr CDN（大陆网络可达，缓存约 12 小时）→ GitHub API
  /// （匿名限流 60 次/小时/IP，仅作最终兜底）。
  /// raw / jsdelivr 网络不可达或 5xx 才继续下一通道；4xx / 内容非法不降级。
  Future<UpdateCheckResult> checkForUpdate() async {
    if (!configured) {
      LogService.instance.info('update.check skip: repo not configured');
      return const UpdateCheckResult(UpdateCheckState.notConfigured);
    }
    LogService.instance.info(
      'update.check start (current=$currentVersion, '
      'raw=${UpdateConfig.latestInfoUrl})',
    );
    var r = await _checkJson('raw', UpdateConfig.latestInfoUrl);
    if (_decided(r)) {
      _logDecided('raw', r);
      return r;
    }
    r = await _checkJson('jsdelivr', UpdateConfig.jsdelivrInfoUrl);
    if (_decided(r)) {
      _logDecided('jsdelivr', r);
      return r;
    }
    LogService.instance.info('update.check fallback -> github api');
    return _checkViaApi();
  }

  /// 结果已"定论"时记录命中通道与状态。
  /// 无新版本信息（upToDate / 内容问题）时不输出 tag，避免 "-" 占位误解。
  static void _logDecided(String channel, UpdateCheckResult r) {
    final tag = r.info?.tagName;
    final tail = tag == null ? '' : ' tag=$tag';
    LogService.instance.info('update.check $channel decided '
        'state=${r.state.name}$tail');
  }

  /// 该结果是否已"定论"（无需再尝试下一通道）。
  static bool _decided(UpdateCheckResult r) =>
      r.state == UpdateCheckState.updateAvailable ||
      r.state == UpdateCheckState.upToDate ||
      r.state == UpdateCheckState.httpError;

  /// 请求单个 JSON 版本信息文件（raw / jsdelivr 共用）。
  Future<UpdateCheckResult> _checkJson(String channel, String url) async {
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode == 404) {
        await resp.drain<void>();
        LogService.instance.info('update.check $channel http 404');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        LogService.instance
            .info('update.check $channel http ${resp.statusCode}');
        return const UpdateCheckResult(UpdateCheckState.serverError);
      }
      final body = await resp.transform(utf8.decoder).join();
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        LogService.instance.info('update.check $channel bad-json');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      final version = (json['version'] as String? ?? '').trim();
      if (version.isEmpty) {
        LogService.instance.info('update.check $channel empty-version');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      final assets = <ReleaseAsset>[];
      final assetMap = json['assets'] as Map<String, dynamic>? ?? const {};
      assetMap.forEach((platform, url) {
        final s = url as String? ?? '';
        if (s.isEmpty) return;
        assets.add(ReleaseAsset(name: s.split('/').last, downloadUrl: s));
      });
      if (assets.isEmpty) {
        LogService.instance.info('update.check $channel no-assets');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      final tag = 'v$version';
      // 只有远端版本比当前新才提示
      if (compareVersions(_stripV(tag), currentVersion) <= 0) {
        LogService.instance.info(
            'update.check $channel ok up-to-date remote=$tag');
        return const UpdateCheckResult(UpdateCheckState.upToDate);
      }
      LogService.instance
          .info('update.check $channel ok update-available tag=$tag');
      return UpdateCheckResult(
        UpdateCheckState.updateAvailable,
        ReleaseInfo(tagName: tag, assets: assets),
      );
    } on SocketException {
      LogService.instance.info('update.check $channel socket-error');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } on HttpException {
      LogService.instance.info('update.check $channel http-exception');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } on TimeoutException {
      LogService.instance.info('update.check $channel timeout');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } catch (_) {
      // 其余异常（连接中断等）视作网络层问题，保守重试
      LogService.instance.info('update.check $channel unknown-error');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } finally {
      client.close();
    }
  }

  Future<UpdateCheckResult> _checkViaApi() async {
    final client = _client();
    try {
      final req = await client.getUrl(
        Uri.parse('$_apiBase/repos/$owner/$repo/releases/latest'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close();
      if (resp.statusCode == 404) {
        await resp.drain<void>();
        LogService.instance.info('update.check api http 404');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        LogService.instance
            .info('update.check api http ${resp.statusCode}');
        return const UpdateCheckResult(UpdateCheckState.serverError);
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      if (tag.isEmpty) return const UpdateCheckResult(UpdateCheckState.httpError);
      // 只有远端版本比当前新才提示
      if (compareVersions(_stripV(tag), currentVersion) <= 0) {
        LogService.instance.info(
            'update.check api ok up-to-date remote=$tag');
        return const UpdateCheckResult(UpdateCheckState.upToDate);
      }
      final assets = <ReleaseAsset>[];
      for (final item in json['assets'] as List? ?? const []) {
        final m = item as Map<String, dynamic>;
        final url = m['browser_download_url'] as String? ?? '';
        if (url.isEmpty) continue;
        assets.add(ReleaseAsset(
          name: m['name'] as String? ?? url,
          downloadUrl: url,
        ));
      }
      if (assets.isEmpty) {
        LogService.instance.info('update.check api no-assets');
        return const UpdateCheckResult(UpdateCheckState.httpError);
      }
      LogService.instance
          .info('update.check api ok update-available tag=$tag');
      return UpdateCheckResult(
        UpdateCheckState.updateAvailable,
        ReleaseInfo(tagName: tag, assets: assets),
      );
    } on SocketException {
      LogService.instance.info('update.check api socket-error');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } on HttpException {
      LogService.instance.info('update.check api http-exception');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } on TimeoutException {
      LogService.instance.info('update.check api timeout');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } catch (_) {
      LogService.instance.info('update.check api unknown-error');
      return const UpdateCheckResult(UpdateCheckState.networkError);
    } finally {
      client.close();
    }
  }

  /// 下载资源到系统临时目录，返回文件；[onProgress] 进度 0~1。
  /// 失败返回 null。
  Future<File?> downloadAsset(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    LogService.instance.info('update.download start url=${asset.downloadUrl}');
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse(asset.downloadUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        LogService.instance
            .info('update.download fail http ${resp.statusCode}');
        return null;
      }
      final total = resp.contentLength;
      final file = File('${Directory.systemTemp.path}/${asset.name}');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.close();
      LogService.instance
          .info('update.download ok bytes=$received -> ${file.path}');
      return file;
    } catch (_) {
      LogService.instance.info('update.download fail unknown-error');
      return null;
    } finally {
      client.close();
    }
  }

  /// 启动安装器，返回是否已成功启动安装流程。
  ///
  /// 只负责"启动"安装进程，**不等待**安装完成：调用方应在启动后立即退出
  /// 本应用，让安装流程在应用退出后完成（Windows 安装器若触发 UAC 提权，
  /// 由安装器自行处理；之前用 Process.run 等待导致安装器卡在"应用仍在运行"）。
  ///
  /// 平台差异：
  /// - Windows：Inno Setup 安装包，静默安装（/VERYSILENT /NORESTART）。
  /// - macOS：dmg → 挂载 → ditto 替换 /Applications/SimpleClock.app → open 新版。
  /// - Linux：AppImage → install 复制到 ~/.local/bin → 等旧实例退出后启动新版。
  Future<bool> launchInstaller(File installer) async {
    LogService.instance.info(
      'update.launch start platform=$Platform.operatingSystem '
      'installer=${installer.path}',
    );
    try {
      if (Platform.isWindows) {
        await Process.start(
          installer.path,
          const ['/VERYSILENT', '/NORESTART'],
          runInShell: false,
        );
        LogService.instance.info('update.launch ok (windows)');
        return true;
      }
      if (Platform.isMacOS) {
        final script = await _writeTempScript(_macUpdaterScript);
        await Process.start(
          '/bin/bash',
          [script.path, installer.path],
          runInShell: false,
        );
        LogService.instance.info('update.launch ok (macos)');
        return true;
      }
      if (Platform.isLinux) {
        final script = await _writeTempScript(_linuxUpdaterScript);
        await Process.start(
          '/bin/bash',
          [script.path, installer.path],
          runInShell: false,
        );
        LogService.instance.info('update.launch ok (linux)');
        return true;
      }
      LogService.instance.info('update.launch unsupported-platform');
      return false;
    } catch (e) {
      LogService.instance.info('update.launch fail: $e');
      return false;
    }
  }

  /// 当前平台对应的安装包资产（Windows .exe / macOS .dmg / Linux .AppImage）。
  ReleaseAsset? platformAsset(ReleaseInfo info) {
    if (Platform.isWindows) return info.assetFor({'.exe'});
    if (Platform.isMacOS) return info.assetFor({'.dmg'});
    if (Platform.isLinux) return info.assetFor({'.appimage'});
    return null;
  }

  /// macOS 更新脚本：挂载 dmg → ditto 替换 /Applications 里的旧版 → open 新版。
  /// 以独立 bash 进程运行，应用退出后继续执行；$1 = 下载的 dmg 路径。
  static const String _macUpdaterScript = r'''#!/bin/bash
# SimpleClock updater (macOS)
DMG="$1"
APP="/Applications/SimpleClock.app"
MOUNT_OUT=$(hdiutil attach "$DMG" -nobrowse -readonly -quiet 2>/dev/null) || exit 1
MOUNT_POINT=$(echo "$MOUNT_OUT" | awk '{print $NF}' | grep '^/Volumes/' | tail -n 1)
if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT/SimpleClock.app" ]; then
  [ -n "$MOUNT_POINT" ] && hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
  exit 1
fi
# ditto 原子替换旧版（保留权限与签名属性）
ditto "$MOUNT_POINT/SimpleClock.app" "$APP"
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
# 旧实例已退出，启动新版
open "$APP"
exit 0
''';

  /// Linux 更新脚本：复制 AppImage 到 ~/.local/bin → 等旧实例退出 → 启动新版。
  /// 以独立 bash 进程运行，应用退出后继续执行；$1 = 下载的 AppImage 路径。
  static const String _linuxUpdaterScript = r'''#!/bin/bash
# SimpleClock updater (Linux)
SRC="$1"
DEST="$HOME/.local/bin/SimpleClock.AppImage"
mkdir -p "$(dirname "$DEST")"
install -m 755 "$SRC" "$DEST"
# 等待旧实例完全退出（单实例锁端口释放）后再启动新版
sleep 3
nohup "$DEST" >/dev/null 2>&1 &
exit 0
''';

  /// 把脚本内容写入临时文件，返回文件引用。
  Future<File> _writeTempScript(String content) async {
    final script = File('${Directory.systemTemp.path}/simpleclock_update.sh');
    await script.writeAsString(content);
    return script;
  }

  HttpClient _client() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'simple_clock_updater';
    return client;
  }

  static String _stripV(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  /// 语义化版本比对（供测试）。
  /// >0 表示 a 更新，==0 相等，<0 表示 a 更旧。
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map(int.tryParse).whereType<int>().toList();
    final pb = b.split('.').map(int.tryParse).whereType<int>().toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }
}
