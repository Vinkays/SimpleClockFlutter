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

/// 热键 → 用户可读标签（如 Ctrl+Alt+Shift+T；macOS 用 ⌃⌥⇧⌘ 符号）。
String formatHotkey(HotKey hotKey) {
  final parts = <String>[
    for (final m in hotKey.modifiers ?? const <HotKeyModifier>[])
      switch (m) {
        HotKeyModifier.control => Platform.isMacOS ? '⌃' : 'Ctrl',
        HotKeyModifier.alt => Platform.isMacOS ? '⌥' : 'Alt',
        HotKeyModifier.shift => Platform.isMacOS ? '⇧' : 'Shift',
        HotKeyModifier.meta => Platform.isMacOS ? '⌘' : 'Win',
        HotKeyModifier.capsLock => 'Caps',
        HotKeyModifier.fn => 'Fn',
      },
    _physicalKeyLabel(hotKey.physicalKey),
  ];
  return parts.join('+');
}

/// 物理键 → 显示名（Key T→T、Digit 1→1、F1→F1、Space→Space、Arrow Up→↑ 等）。
String _physicalKeyLabel(PhysicalKeyboardKey key) {
  final name = key.debugName ?? '';
  if (name.startsWith('Key ')) return name.substring(4);
  if (name.startsWith('Digit ')) return name.substring(6);
  if (name.startsWith('Numpad ')) return '小键盘${name.substring(7)}';
  return switch (name) {
    'Escape' => 'Esc',
    'Arrow Up' => '↑',
    'Arrow Down' => '↓',
    'Arrow Left' => '←',
    'Arrow Right' => '→',
    _ => name,
  };
}
