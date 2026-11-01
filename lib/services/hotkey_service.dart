import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:uni_platform/uni_platform.dart';

/// 置顶快捷键全局热键服务（三平台）。
///
/// - Windows：Win32 `RegisterHotKey`（用户级全局热键，无需管理员权限；
///   热键与线程/窗口关联，退出进程时自动释放）
/// - macOS：Carbon `RegisterEventHotKey`
/// - Linux：X11 `XGrabKey`（Wayland 下受桌面环境支持限制）
///
/// 注意：`hotkey_manager_windows` 插件不检查 `RegisterHotKey` 的返回值，
/// 组合键被其他程序占用时会静默失败（错误码 1409）；
/// 因此 Windows 平台注册前先用 FFI 探测目标组合是否可用
/// （探测注册成功后立即释放，不长期占用）。
class HotkeyService {
  HotkeyService();

  HotKey? _registered;
  bool _disposed = false;

  /// 当前已注册的热键（null 表示未注册）。
  HotKey? get registered => _registered;

  /// 注册热键并绑定触发回调；返回是否注册成功。
  ///
  /// 注册前先注销旧热键；Windows 上先探测冲突，
  /// 组合键已被其他程序占用时返回 false（不注册、不报错）。
  Future<bool> register(HotKey hotKey, {VoidCallback? onTrigger}) async {
    if (_disposed) return false;
    await unregister();
    if (Platform.isWindows && !await _probeAvailableWindows(hotKey)) {
      return false;
    }
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: onTrigger == null ? null : (_) => onTrigger(),
      );
      _registered = hotKey;
      return true;
    } catch (_) {
      // 平台不支持或注册异常：保持未注册状态，由调用方决定提示
      _registered = null;
      return false;
    }
  }

  /// 注销当前热键（若有）。
  Future<void> unregister() async {
    final hk = _registered;
    if (hk == null) return;
    try {
      await hotKeyManager.unregister(hk);
    } catch (_) {
      // 注销失败不致命：进程退出时系统会回收热键
    }
    _registered = null;
  }

  /// 释放服务（应用退出时调用，注销全部热键）。
  Future<void> dispose() async {
    _disposed = true;
    await unregister();
  }
}

// ==================== Windows 冲突探测（dart:ffi） ====================

typedef _RegisterHotKeyNative = Int32 Function(
    Pointer<Void>? hWnd, Int32 id, Uint32 fsModifiers, Uint32 vk);
typedef _RegisterHotKeyDart = int Function(
    Pointer<Void>? hWnd, int id, int fsModifiers, int vk);
typedef _UnregisterHotKeyNative = Int32 Function(
    Pointer<Void>? hWnd, Int32 id);
typedef _UnregisterHotKeyDart = int Function(Pointer<Void>? hWnd, int id);
typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

/// Windows：探测组合键是否可注册（未被其他程序占用）。
/// 非 Windows 平台无法探测，一律视为可用。
Future<bool> _probeAvailableWindows(HotKey hotKey) async {
  if (!Platform.isWindows) return true;
  // 测试环境（flutter test）不触碰真实系统热键，直接视为可用
  if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final registerHotKey = user32.lookupFunction<_RegisterHotKeyNative,
        _RegisterHotKeyDart>('RegisterHotKey');
    final unregisterHotKey = user32.lookupFunction<_UnregisterHotKeyNative,
        _UnregisterHotKeyDart>('UnregisterHotKey');
    final getLastError =
        user32.lookupFunction<_GetLastErrorNative, _GetLastErrorDart>(
            'GetLastError');

    // 探测用独立热键 id（避开 hotkey_manager 内部自增 id）
    const probeId = 0x51454B59; // 'QKEY'
    // hWnd 传 null：热键与当前线程关联，探测后立即释放
    final hwnd = null;
    // Windows 上 PhysicalKeyboardKey.keyCode 即 VK 码（uni_platform 扩展，
    // 与 hotkey_manager 插件注册时用的键码一致）；取不到则无法探测
    final vk = hotKey.physicalKey.keyCode;
    if (vk == null) return true;
    final mods = _fsModifiers(hotKey.modifiers ?? const []);
    if (registerHotKey(hwnd, probeId, mods, vk) == 0) {
      // 1409 = ERROR_HOTKEY_ALREADY_REGISTERED → 组合键已被其他程序占用
      return getLastError() != 1409;
    }
    // 探测成功：立即释放，避免自己占用该组合导致随后注册失败
    unregisterHotKey(hwnd, probeId);
    return true;
  } catch (_) {
    // 探测失败（如 FFI 不可用）不阻塞，按可用处理
    return true;
  }
}

/// 修饰键 → Win32 修饰位（与 hotkey_manager_windows 插件映射一致）。
int _fsModifiers(List<HotKeyModifier> modifiers) {
  var fs = 0;
  for (final m in modifiers) {
    switch (m) {
      case HotKeyModifier.alt:
        fs |= 0x0001; // MOD_ALT
      case HotKeyModifier.control:
        fs |= 0x0002; // MOD_CONTROL
      case HotKeyModifier.shift:
        fs |= 0x0004; // MOD_SHIFT
      case HotKeyModifier.meta:
        fs |= 0x0008; // MOD_WIN
      default:
        break;
    }
  }
  return fs;
}

// ==================== 热键显示格式化 ====================

/// 修饰键统一输出顺序（Ctrl → Alt → Shift → Win → Caps → Fn），
/// 与录制时的枚举遍历顺序无关，保证同一组合显示一致。
const List<HotKeyModifier> _modifierOrder = [
  HotKeyModifier.control,
  HotKeyModifier.alt,
  HotKeyModifier.shift,
  HotKeyModifier.meta,
  HotKeyModifier.capsLock,
  HotKeyModifier.fn,
];

/// 热键 → 用户可读标签（如 Ctrl+Alt+Shift+T；macOS 用 ⌃⌥⇧⌘ 符号）。
String formatHotkey(HotKey hotKey) {
  final mods = (hotKey.modifiers ?? const <HotKeyModifier>[]).toList()
    ..sort((a, b) =>
        _modifierOrder.indexOf(a).compareTo(_modifierOrder.indexOf(b)));
  return [
    for (final m in mods)
      switch (m) {
        HotKeyModifier.control => Platform.isMacOS ? '⌃' : 'Ctrl',
        HotKeyModifier.alt => Platform.isMacOS ? '⌥' : 'Alt',
        HotKeyModifier.shift => Platform.isMacOS ? '⇧' : 'Shift',
        HotKeyModifier.meta => Platform.isMacOS ? '⌘' : 'Win',
        HotKeyModifier.capsLock => 'Caps',
        HotKeyModifier.fn => 'Fn',
      },
    _physicalKeyLabel(hotKey.physicalKey),
  ].join('+');
}

/// 物理键 → 显示名（Key T→T、Digit 1→1、F1→F1、Arrow Up→↑ 等）。
///
/// 注意：`PhysicalKeyboardKey.debugName` 在 **release 构建下恒为 null**
/// （Flutter 用 `kReleaseMode ? {} : {...}` 生成 `_debugNames`，且 getter
/// 只在 assert 中赋值），依赖它会出现在 release 版缺普通键的问题。
/// 因此按 USB HID 用法码（`usbHidUsage` 为 const 字段，release 下仍在）
/// 自建映射，保证 debug/release 显示一致。
String _physicalKeyLabel(PhysicalKeyboardKey key) {
  final code = key.usbHidUsage & 0xFF;
  // 字母区：0x04-0x1D → A-Z
  if (code >= 0x04 && code <= 0x1D) {
    return String.fromCharCode(0x41 + code - 0x04);
  }
  // 数字行：0x1E-0x26 → 1-9，0x27 → 0
  if (code >= 0x1E && code <= 0x26) {
    return String.fromCharCode(0x31 + code - 0x1E);
  }
  if (code == 0x27) return '0';
  // 功能键：0x3A-0x45 → F1-F12
  if (code >= 0x3A && code <= 0x45) return 'F${code - 0x3A + 1}';
  // 方向键：0x4F-0x52 → → ← ↓ ↑
  if (code >= 0x4F && code <= 0x52) {
    return const ['→', '←', '↓', '↑'][code - 0x4F];
  }
  // 小键盘数字：0x59-0x61 → 小键盘1-9，0x62 → 小键盘0，0x63 → 小键盘.
  if (code >= 0x59 && code <= 0x61) return '小键盘${code - 0x59 + 1}';
  if (code == 0x62) return '小键盘0';
  if (code == 0x63) return '小键盘.';
  return switch (code) {
    0x28 => 'Enter',
    0x29 => 'Esc',
    0x2A => 'Backspace',
    0x2B => 'Tab',
    0x2C => 'Space',
    0x2D => '-',
    0x2E => '=',
    0x2F => '[',
    0x30 => ']',
    0x31 => r'\',
    0x33 => ';',
    0x34 => "'",
    0x35 => '`',
    0x36 => ',',
    0x37 => '.',
    0x38 => '/',
    0x39 => 'CapsLock',
    0x46 => 'PrintScreen',
    0x47 => 'ScrollLock',
    0x48 => 'Pause',
    0x49 => 'Insert',
    0x4A => 'Home',
    0x4B => 'PageUp',
    0x4C => 'Delete',
    0x4D => 'End',
    0x4E => 'PageDown',
    0x53 => 'NumLock',
    0x54 => '小键盘/',
    0x55 => '小键盘*',
    0x56 => '小键盘-',
    0x57 => '小键盘+',
    0x58 => '小键盘Enter',
    0x64 => '小键盘=',
    0x65 => '小键盘,',
    _ => 'Key 0x${code.toRadixString(16).padLeft(2, '0')}',
  };
}
