// 简易时钟 Flutter 版的基础冒烟测试。
//
// 使用 SharedPreferences 的 mock 实现，避免真实平台存储依赖；
// 不触发 window_manager 的平台调用（拖动/置顶等方法仅在用户交互时才会调用）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_clock/app.dart';
import 'package:simple_clock/controllers/app_controller.dart';
import 'package:simple_clock/services/single_instance_service.dart';
import 'package:simple_clock/services/store_service.dart';
import 'package:simple_clock/services/update_service.dart';
import 'package:simple_clock/ui/clock_page.dart';

void main() {
  testWidgets('时钟界面渲染并显示时间', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final controller = AppController(store);
    await controller.init();

    await tester.pumpWidget(ClockApp(controller: controller));
    await tester.pump(const Duration(seconds: 1));

    // 时间通过 CustomPaint 绘制（无 Text widget 布局，避免溢出/换行）
    expect(find.byType(CustomPaint), findsWidgets);
    // 渲染过程不应产生任何布局溢出等异常
    expect(tester.takeException(), isNull);
    // 存在背景与文字颜色的自定义外观
    expect(controller.bgColor, isNotNull);

    // 卸载组件，释放计时器
    await tester.pumpWidget(const SizedBox());
  });

  test('外观设置可持久化并可恢复', () async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final controller = AppController(store);
    await controller.init();

    const bg = Color(0xFF123456);
    const text = Color(0xFFABCDEF);
    controller.setAppearance(bg, text);

    // 用新的实例模拟重启后的恢复
    final store2 = StoreService();
    await store2.init();
    final controller2 = AppController(store2);
    await controller2.init();

    expect(controller2.bgColor, bg);
    expect(controller2.textColor, text);
  });

  test('字体设置可持久化并可恢复', () async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final controller = AppController(store);
    await controller.init();

    controller.setTextFontFamily('Consolas');

    // 用新的实例模拟重启后的恢复
    final store2 = StoreService();
    await store2.init();
    final controller2 = AppController(store2);
    await controller2.init();

    expect(controller2.textFontFamily, 'Consolas');
  });

  test('语言设置可持久化并可恢复', () async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final controller = AppController(store);
    await controller.init();

    controller.setLanguage('en');

    // 用新的实例模拟重启后的恢复
    final store2 = StoreService();
    await store2.init();
    final controller2 = AppController(store2);
    await controller2.init();

    expect(controller2.language, 'en');
  });

  test('单实例锁：第二个实例检测到已有实例并退出', () async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final first = SingleInstanceService(store);
    var activated = false;

    // 第一个实例成为唯一实例
    expect(await first.acquire(onActivate: () => activated = true), true);

    // 第二个实例（同一存储）应检测到已有实例
    final second = SingleInstanceService(store);
    expect(await second.acquire(), false);

    // 第一个实例收到激活通知
    expect(activated, true);

    // 释放端口，避免影响其它测试
    await first.dispose();
  });

  test('更新器版本比对逻辑', () {
    expect(UpdateService.compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
    expect(UpdateService.compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(UpdateService.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(UpdateService.compareVersions('2.0.0', '1.99.99'), greaterThan(0));
  });

  testWidgets('所选字体应用到全局主题', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final store = StoreService();
    await store.init();
    final controller = AppController(store);
    await controller.init();
    controller.setTextFontFamily('Consolas');

    await tester.pumpWidget(ClockApp(controller: controller));

    // 从应用内部组件（ClockPage）拿主题，才能取到 MaterialApp 提供的主题
    final context = tester.element(find.byType(ClockPage));
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Consolas');

    await tester.pumpWidget(const SizedBox());
  });
}
