import 'package:flutter/widgets.dart';

/// 界面文案（中文 / English）。
///
/// 轻量 i18n：无 codegen、跨平台（Windows/macOS/Linux）可用。
/// 语言由 [AppController.language] 决定并持久化，
/// 通过 MaterialApp.locale 生效，这里统一维护全部词条。
class AppStrings {
  AppStrings._();

  static const Map<String, String> zh = {
    'appTitle': '简易时钟',
    // 主菜单
    'menuTextColor': '文字颜色',
    'menuBgColor': '背景色',
    'menuFont': '字体',
    'menuLock': '锁定',
    'menuUnlock': '解除锁定',
    'menuPin': '置顶',
    'menuUnpin': '移除置顶',
    'menuAutoStart': '设置开机自启动',
    'menuRemoveAutoStart': '移除开机自启动',
    'menuQuit': '退出程序',
    'menuLanguage': '语言',
    // 通用
    'defaultFont': '默认字体',
    'backToMenu': '返回菜单',
    'cancel': '取消',
    'confirm': '确定',
    // 字体面板
    'pickFont': '选择字体',
    'searchFonts': '搜索字体',
    'noFontsMatch': '没有匹配的字体',
    'fontListHint': '已列出本机已安装字体，可直接选择应用',
    // 选色面板
    'pickTextColor': '选择文字颜色',
    'pickBgColor': '选择背景色',
    'hue': '色相',
    'saturation': '饱和度',
    'brightness': '亮度',
    // 语言面板
    'langFollowSystem': '跟随系统',
    'langFollowSystemDesc': '自动使用系统语言',
    'langChinese': '中文',
    'langChineseDesc': '简体中文',
    'langEnglish': 'English',
    // Toast
    'autoStartSuccess': '设置开机自启动成功',
    'autoStartRemoveSuccess': '移除开机自启动成功',
    'autoStartFailed': '设置开机自启动失败',
    'autoStartFailedDetail': '设置开机自启动失败：',
    // 更新
    'updateAvailableTitle': '发现新版本',
    'updateAvailableBody': '当前版本 {0}，发现新版本 {1}，是否立即更新？',
    'updateNow': '立即更新',
    'updateLater': '稍后',
    'updateDownloading': '正在下载更新…（{0}%）',
    'updateLaunching': '下载完成，正在启动安装程序，应用将自动退出…',
    'updateFailed': '更新下载失败，请稍后重试',
  };

  static const Map<String, String> en = {
    'appTitle': 'SimpleClock',
    // Main menu
    'menuTextColor': 'Text Color',
    'menuBgColor': 'Background',
    'menuFont': 'Font',
    'menuLock': 'Lock',
    'menuUnlock': 'Unlock',
    'menuPin': 'Pin on Top',
    'menuUnpin': 'Remove Pin',
    'menuAutoStart': 'Auto Start',
    'menuRemoveAutoStart': 'Remove Auto Start',
    'menuQuit': 'Quit',
    'menuLanguage': 'Language',
    // Common
    'defaultFont': 'Default Font',
    'backToMenu': 'Back',
    'cancel': 'Cancel',
    'confirm': 'OK',
    // Font panel
    'pickFont': 'Select Font',
    'searchFonts': 'Search fonts',
    'noFontsMatch': 'No matching fonts',
    'fontListHint': 'All installed system fonts are listed; tap to apply',
    // Color panel
    'pickTextColor': 'Text Color',
    'pickBgColor': 'Background Color',
    'hue': 'Hue',
    'saturation': 'Sat.',
    'brightness': 'Bright',
    // Language panel
    'langFollowSystem': 'Follow System',
    'langFollowSystemDesc': 'Use system language',
    'langChinese': 'Chinese (Simplified)',
    'langChineseDesc': 'Simplified Chinese',
    'langEnglish': 'English',
    // Toast
    'autoStartSuccess': 'Auto start enabled',
    'autoStartRemoveSuccess': 'Auto start removed',
    'autoStartFailed': 'Failed to enable auto start',
    'autoStartFailedDetail': 'Failed to enable auto start: ',
    // Update
    'updateAvailableTitle': 'New version available',
    'updateAvailableBody': 'Current {0}, found {1}. Update now?',
    'updateNow': 'Update Now',
    'updateLater': 'Later',
    'updateDownloading': 'Downloading update… ({0}%)',
    'updateLaunching': 'Download done, launching installer. The app will quit…',
    'updateFailed': 'Update download failed, please retry later',
  };

  /// 当前界面的文案表（依赖 MaterialApp 的 locale）。
  static Map<String, String> of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'en' ? en : zh;
  }

  /// 语言设置值 -> MaterialApp.locale（null 表示跟随系统）。
  static Locale? localeFor(String language) {
    switch (language) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return null; // 跟随系统
    }
  }
}
