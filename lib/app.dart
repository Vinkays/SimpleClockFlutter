import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'controllers/app_controller.dart';
import 'services/app_strings.dart';
import 'ui/clock_page.dart';

/// 应用根组件：监听窗口事件、提供全局主题。
class ClockApp extends StatefulWidget {
  const ClockApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ClockApp> createState() => _ClockAppState();
}

class _ClockAppState extends State<ClockApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // 关闭窗口：先持久化状态再销毁（quitApp 内部有防重入保护）
    widget.controller.quitApp();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          // 窗口标题不随 locale 动态重建，直接按语言设置取值
          title: widget.controller.language == 'en' ? 'SimpleClock' : '简易时钟',
          debugShowCheckedModeBanner: false,
          // 界面语言：跟随系统 / 中文 / English（null 表示跟随系统）
          locale: AppStrings.localeFor(widget.controller.language),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh'),
            Locale('en'),
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A3A3A)),
            // 全局字体跟随设置：时钟、右键菜单、按钮等所有界面文本统一切换。
            // 注意：Material 3 下 ThemeData(fontFamily:) 不会覆盖 textTheme，
            // 必须显式用 Typography.apply(fontFamily:) 生成 textTheme。
            textTheme: Typography.material2021().black.apply(
              fontFamily: widget.controller.textFontFamily,
            ),
          ),
          home: ClockPage(controller: widget.controller),
        );
      },
    );
  }
}
