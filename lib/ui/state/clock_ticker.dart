part of '../clock_page.dart';

/// 时钟走时：整秒对齐启动 + 每秒更新。
mixin ClockTickerMixin on State<ClockPage> {
  Timer? _timer;
  String _hour = '00';
  String _minute = '00';
  String _second = '00';

  /// 对齐到下一个整秒再开始周期更新（initState 调用一次）：
  /// 避免首帧渲染耗时（尤其 debug 模式）导致 tick 相位漂移，
  /// 让每次更新都落在系统秒边界附近，显示的秒始终是真实当前秒。
  void _startClockTicker() {
    _updateTime();
    final now = DateTime.now();
    final msToNextSecond = 1000 - now.millisecond;
    _timer = Timer(Duration(milliseconds: msToNextSecond), () {
      _updateTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (h != _hour || m != _minute || s != _second) {
      setState(() {
        _hour = h;
        _minute = m;
        _second = s;
      });
    }
  }

  void _disposeClockTicker() => _timer?.cancel();
}
