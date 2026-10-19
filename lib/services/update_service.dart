import 'dart:convert';
import 'dart:io';

import 'update_config.dart';

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

  /// 检查是否有新版本。无更新 / 未配置 / 网络失败均返回 null。
  ///
  /// 优先读取 raw.githubusercontent.com 的版本信息文件（CDN、无 API 限流），
  /// 失败时回退 GitHub API（匿名限流 60 次/小时/IP，仅作兜底）。
  Future<ReleaseInfo?> checkForUpdate() async {
    if (!configured) return null;
    return await _checkViaLatestJson() ?? await _checkViaApi();
  }

  Future<ReleaseInfo?> _checkViaLatestJson() async {
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse(UpdateConfig.latestInfoUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return null;
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final version = (json['version'] as String? ?? '').trim();
      if (version.isEmpty) return null;
      final assets = <ReleaseAsset>[];
      final assetMap = json['assets'] as Map<String, dynamic>? ?? const {};
      assetMap.forEach((platform, url) {
        final s = url as String? ?? '';
        if (s.isEmpty) return;
        assets.add(ReleaseAsset(name: s.split('/').last, downloadUrl: s));
      });
      if (assets.isEmpty) return null;
      final tag = 'v$version';
      // 只有远端版本比当前新才提示
      if (compareVersions(_stripV(tag), currentVersion) <= 0) return null;
      return ReleaseInfo(tagName: tag, assets: assets);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<ReleaseInfo?> _checkViaApi() async {
    final client = _client();
    try {
      final req = await client.getUrl(
        Uri.parse('$_apiBase/repos/$owner/$repo/releases/latest'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return null;
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      if (tag.isEmpty) return null;
      // 只有远端版本比当前新才提示
      if (compareVersions(_stripV(tag), currentVersion) <= 0) return null;
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
      return ReleaseInfo(tagName: tag, assets: assets);
    } catch (_) {
      return null;
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
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse(asset.downloadUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        await resp.drain<void>();
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
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// 启动安装器（Windows：Inno Setup 静默安装；其它平台返回 false）。
  Future<bool> launchInstaller(File installer) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          installer.path,
          const ['/VERYSILENT', '/NORESTART'],
          runInShell: false,
        );
        return result.exitCode == 0;
      }
      return false;
    } catch (_) {
      return false;
    }
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
