part of '../clock_page.dart';

/// 时钟走时：整秒对齐启动 + 每秒更新。
///
/// 时间制式由 [AppController.effective12Hour] 决定：
/// - 12 小时制：小时转换为 1-12，并输出 AM/PM 文案（由 ScaledClock 拼在秒数后）；
/// - 24 小时制：小时保持 0-23，[amPm] 为 null（不显示 AM/PM）。
mixin ClockTickerMixin on State<ClockPage> {
  Timer? _timer;
  String _hour = '00';
  String _minute = '00';
  String _second = '00';

  /// 12 小时制的 AM/PM 文案（null = 24 小时制，不显示）。
  String? _amPm;

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

  /// 时间制式等设置变化时立即刷新显示（否则要等下一个整秒 tick 才生效）。
  void _onClockSettingsChanged() {
    if (mounted) _updateTime();
  }

  void _updateTime() {
    final now = DateTime.now();
    final use12Hour = widget.controller.effective12Hour;
    final h24 = now.hour;
    String h;
    String? amPm;
    if (use12Hour) {
      // 12 小时制：0 点与 12 点都显示 12，其余取模；午夜前为 AM，午后为 PM
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      h = h12.toString().padLeft(2, '0');
      amPm = h24 < 12 ? 'AM' : 'PM';
    } else {
      h = h24.toString().padLeft(2, '0');
    }
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (h != _hour || m != _minute || s != _second || amPm != _amPm) {
      setState(() {
        _hour = h;
        _minute = m;
        _second = s;
        _amPm = amPm;
      });
    }
  }

  void _disposeClockTicker() {
    _timer?.cancel();
    widget.controller.removeListener(_onClockSettingsChanged);
  }
}
