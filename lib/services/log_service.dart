import 'dart:io';

/// 应用日志：开关控制写入，落盘到平台标准用户数据目录，
/// 「打开日志文件」用系统默认编辑器查看（外部窗口，不占用工具窗）。
///
/// 记录更新检查链路每一步（通道命中/HTTP 状态/退避/冷却/下载），
/// 用于远程诊断 macOS/Linux 用户"收不到更新提示"等问题。
class LogService {
  LogService._();

  static final LogService instance = LogService._();

  static const String _fileName = 'simple_clock.log';
  static const int _maxBytes = 512 * 1024;
  static const int _maxLines = 2000;

  bool _enabled = false;
  bool _dirChecked = false;
  Directory? _logDir;

  /// 写入队列：所有 [info] 按调用顺序串行执行。
  /// 插入最前是「读全部 → 整体写回」的非原子操作，并发执行会切碎/丢行
  /// （如日志里出现孤立的 tag=v0.0.10 碎片），必须排队串行化。
  Future<void> _writeTail = Future<void>.value();

  /// 是否开启日志写入（由 AppController 开关同步）。
  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }

  /// 日志目录（平台标准用户数据目录）：
  /// - Windows：%APPDATA%/SimpleClock/logs
  /// - macOS：~/Library/Application Support/SimpleClock/logs
  /// - Linux：~/.local/share/SimpleClock/logs
  String get _logDirPath {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      return '$appData/SimpleClock/logs';
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Library/Application Support/SimpleClock/logs';
    }
    final home = Platform.environment['HOME'];
    return '$home/.local/share/SimpleClock/logs';
  }

  /// 写入一条日志（开关关闭 / 目录不可写时静默跳过）。
  /// 新日志插入文件最前（最新的在最上面，打开即见）；
  /// 通过队列串行化写入，防止并发读写同一文件造成内容错位。
  Future<void> info(String message) async {
    if (!_enabled) return;
    final line = '${DateTime.now().toIso8601String()}  $message\n';
    // 排队串行执行；单条失败不影响后续写入
    _writeTail = _writeTail
        .then((_) => _writeLine(line))
        .catchError((_) {});
    await _writeTail;
  }

  Future<void> _writeLine(String line) async {
    try {
      final dir = await _ensureDir();
      if (dir == null) return;
      final file = File('${dir.path}/$_fileName');
      // 超过大小上限：轮转为 .1（下次再满直接覆盖，最多保留两份）
      if (await file.exists() && await file.length() > _maxBytes) {
        final backup = File('${dir.path}/$_fileName.1');
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      if (!await file.exists()) {
        await file.writeAsString(line);
      } else {
        final old = await file.readAsString();
        await file.writeAsString('$line$old');
      }
    } catch (_) {
      // 日志失败不影响主流程
    }
  }

  /// 当前日志文件（未开启或不存在时返回 null）。
  Future<File?> logFile() async {
    if (!_enabled) return null;
    try {
      final dir = await _ensureDir();
      if (dir == null) return null;
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) return null;
      // 超出行数上限时截断：新日志在文件最前，保留顶部（最新）_maxLines 行，
      // 避免打开时内容过长
      final lines = await file.readAsLines();
      if (lines.length > _maxLines) {
        final kept = lines.sublist(0, _maxLines);
        await file.writeAsString('${kept.join('\n')}\n');
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _ensureDir() async {
    if (_dirChecked) return _logDir;
    _dirChecked = true;
    try {
      final dir = Directory(_logDirPath);
      await dir.create(recursive: true);
      _logDir = dir;
    } catch (_) {
      _logDir = null;
    }
    return _logDir;
  }
}
