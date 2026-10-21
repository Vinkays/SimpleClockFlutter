import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'services/single_instance_service.dart';
import 'services/store_service.dart';
import 'services/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化持久化存储与应用状态
  final store = StoreService();
  await store.init();
  final controller = AppController(store);
  await controller.init();

  // 单实例锁：已有实例在运行时，通知它聚焦并让本实例直接退出
  // （与原版 Electron requestSingleInstanceLock 行为一致）
  final singleInstance = SingleInstanceService(store);
  final isPrimary = await singleInstance.acquire(onActivate: () async {
    try {
      // 窗口可能隐藏在托盘，先 show 再 focus
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  });
  if (!isPrimary) return;
  // 挂载到控制器：退出（quitApp）时先释放单实例端口
  controller.attachSingleInstance(singleInstance);

  // 初始化窗口管理器（无边框窗口）
  await windowManager.ensureInitialized();

  final saved = controller.windowSize;
  final initialSize = Size(
    (saved?.width ?? AppController.kDefaultWindowSize.width)
        .clamp(AppController.kMinWindowSize.width, 5000.0),
    (saved?.height ?? AppController.kDefaultWindowSize.height)
        .clamp(AppController.kMinWindowSize.height, 5000.0),
  );

  final options = WindowOptions(
    size: initialSize,
    minimumSize: AppController.kMinWindowSize,
    center: false,
    backgroundColor: controller.bgColor,
    title: '简易时钟',
    // 无边框隐藏标题栏（对应原版 frame: false / titleBarStyle: hidden），
    // window_manager 在隐藏标题栏时保留窗口边缘缩放能力
    titleBarStyle: TitleBarStyle.hidden,
    // macOS：隐藏窗口左上角红绿灯按钮（关闭/最小化/全屏）；
    // 关闭走托盘「退出」，不依赖红绿灯
    windowButtonVisibility: false,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    final savedPos = controller.windowPosition;
    if (savedPos != null) {
      await windowManager.setPosition(
        await _clampToVisibleScreen(savedPos, initialSize),
      );
    } else {
      await windowManager.center();
    }
    await windowManager.setAlwaysOnTop(controller.isAlwaysOnTop);
    if (Platform.isMacOS && controller.isAlwaysOnTop) {
      // macOS 多桌面：置顶窗口只在当前 Space 生效，启动恢复时
      // 同步"所有桌面可见"（canJoinAllSpaces），保证各桌面均置顶
      await windowManager.setVisibleOnAllWorkspaces(true);
    }
    await windowManager.setResizable(!controller.isLocked);
    // 拦截默认关闭：先持久化窗口状态，再真正销毁窗口
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ClockApp(controller: controller));

  // 初始化系统托盘（工具栏窗口的配套入口：恢复窗口 / 退出）。
  // 失败（如无托盘环境）时自动降级为"关闭=退出"，不影响使用。
  final isEn = controller.language == 'en';
  await TrayService.instance.init(
    tooltip: isEn ? 'SimpleClock' : '简易时钟',
    menu: [
      MenuItem(
        key: 'show',
        label: isEn ? 'Show Clock' : '显示时钟',
      ),
      MenuItem(
        key: 'quit',
        label: isEn ? 'Quit' : '退出',
      ),
    ],
    onShow: () async {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
    },
    onQuit: () => controller.quitApp(),
  );
}

/// 将保存的窗口位置钳制到可见屏幕范围内（多显示器场景）。
/// 窗口若完整落在任一显示器内则原样保留；否则归位到主屏可见区域。
Future<Offset> _clampToVisibleScreen(Offset pos, Size winSize) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) return pos;

    final fullyVisible = displays.any((d) {
      final dp = d.visiblePosition;
      final ds = d.visibleSize;
      if (dp == null || ds == null) return false;
      final left = dp.dx;
      final top = dp.dy;
      final right = left + ds.width;
      final bottom = top + ds.height;
      return pos.dx >= left - 1 &&
          pos.dy >= top - 1 &&
          pos.dx + winSize.width <= right + 1 &&
          pos.dy + winSize.height <= bottom + 1;
    });
    if (fullyVisible) return pos;

    // 归位到主显示器可见区域
    final primary = await screenRetriever.getPrimaryDisplay();
    final dp = primary.visiblePosition ?? Offset.zero;
    final ds = primary.visibleSize ?? primary.size;
    final left = dp.dx;
    final top = dp.dy;
    final right = left + ds.width;
    final bottom = top + ds.height;
    final maxX = (right - winSize.width).clamp(left, right);
    final maxY = (bottom - winSize.height).clamp(top, bottom);
    return Offset(
      pos.dx.clamp(left, maxX).toDouble(),
      pos.dy.clamp(top, maxY).toDouble(),
    );
  } catch (_) {
    return pos;
  }
}
