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
    'menuTimeFormat': '时间制式',
    'menuRemindInterval': '更新提醒间隔',
    'menuDebugLog': '调试日志',
    'debugLogOn': '开',
    'debugLogOff': '关',
    'menuAbout': '关于我们',
    // 关于我们面板
    'aboutTitle': '关于我们',
    'aboutAppName': '简易时钟',
    'aboutVersionLabel': '当前版本',
    'aboutCheckUpdate': '检查更新',
    'aboutOpenLog': '打开日志文件',
    'noLogFile': '暂无日志文件',
    'updateUpToDate': '已是最新版',
    'updateCheckFailed': '检查更新失败',
    'updateCheckRetry': '检查更新失败，将自动重试',
    // 更新提醒间隔面板
    'remindIntervalTitle': '更新提醒间隔',
    'remindIntervalDesc': '点击「稍后」后，该版本过多久再次提醒',
    'hours6': '6 小时',
    'hours12': '12 小时',
    'hours24': '24 小时',
    'hours48': '48 小时',
    'hours72': '72 小时',
    'hoursCustom': '自定义（小时）',
    'customHoursHint': '输入小时数',
    'customHoursInvalid': '请输入 1-8760 之间的小时数',
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
    // 时间制式面板
    'timeFollowSystem': '跟随系统',
    'timeFollowSystemDesc': '自动使用系统时间制式',
    'time12Hour': '12 小时制',
    'time12HourDesc': '显示 AM/PM',
    'time24Hour': '24 小时制',
    'time24HourDesc': '不显示 AM/PM',
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
    'menuTimeFormat': 'Time Format',
    'menuRemindInterval': 'Update Reminder',
    'menuDebugLog': 'Debug Log',
    'debugLogOn': 'On',
    'debugLogOff': 'Off',
    'menuAbout': 'About',
    // About panel
    'aboutTitle': 'About',
    'aboutAppName': 'Simple Clock',
    'aboutVersionLabel': 'Version',
    'aboutCheckUpdate': 'Check for Updates',
    'aboutOpenLog': 'Open Log File',
    'noLogFile': 'No log file yet',
    'updateUpToDate': 'Already up to date',
    'updateCheckFailed': 'Update check failed',
    'updateCheckRetry': 'Update check failed, will retry automatically',
    // Update reminder interval panel
    'remindIntervalTitle': 'Update Reminder Interval',
    'remindIntervalDesc': 'How long to wait before reminding again after "Later"',
    'hours6': '6 hours',
    'hours12': '12 hours',
    'hours24': '24 hours',
    'hours48': '48 hours',
    'hours72': '72 hours',
    'hoursCustom': 'Custom (hours)',
    'customHoursHint': 'Enter hours',
    'customHoursInvalid': 'Enter a value between 1 and 8760 hours',
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
    // Time format panel
    'timeFollowSystem': 'Follow System',
    'timeFollowSystemDesc': 'Use system time format',
    'time12Hour': '12-Hour',
    'time12HourDesc': 'Show AM/PM',
    'time24Hour': '24-Hour',
    'time24HourDesc': 'Hide AM/PM',
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
