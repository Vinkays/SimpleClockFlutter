import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'services/single_instance_service.dart';
import 'services/store_service.dart';

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
    await windowManager.setResizable(!controller.isLocked);
    // 拦截默认关闭：先持久化窗口状态，再真正销毁窗口
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ClockApp(controller: controller));
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
