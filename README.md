# SimpleClock（Flutter 版）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

一个简单的桌面时钟应用，使用 **Flutter** 重写自原 Electron + Vue3 项目（[Vinkays/SimpleClock](https://github.com/Vinkays/SimpleClock)）。
支持 **Windows / macOS / Linux** 三个桌面平台。

## 图片预览
![screenshot](/assets/small.jpg)
![screenshot](/assets/selections.jpg)
![screenshot](/assets/color-picker.jpg)

## 功能

- 无边框时钟窗口，实时显示 HH:MM:SS（秒更新对齐系统整秒，时间精确）
- 时间随窗口大小缩放：`CustomPaint` 直接绘制字形，按窗口宽高非等比拉伸，
  并以字形实际边界做视觉居中（任何字体下上下间距均匀）
- 左键拖动窗口（拖动期间锁定窗口尺寸，防止 resize 抖动）
- 窗口边缘 4px 内交给系统缩放窗口
- 右键菜单（窗口内浮层，窗口过小时自动临时撑大，关闭后恢复）：
  - 文字颜色 / 背景色（HSV 颜色选择器 + 预设色块）
  - 字体：列出**本机已安装字体**（Windows 注册表 / macOS 字体目录 / Linux fc-list），
    带搜索框与实时预览；选中后**全局生效**（时钟数字、菜单、选色、字体面板统一切换字体）；
    「默认字体」行带边框 + 下划线标识
  - 语言：跟随系统 / 中文 / English（全部界面文案中英双语，即时切换并持久化）
  - 锁定（禁止拖动与缩放）/ 解除锁定
  - 置顶 / 移除置顶
  - 设置 / 移除开机自启动（Windows 注册表 / macOS 登录项 / Linux autostart）
  - 退出程序
- 操作结果通过应用内 Toast 轻提示（Toast 显示时自动撑大窗口、文字自适应，任何窗口尺寸都完整可见）
- 单实例锁：同时只允许一个实例运行（随机端口占位 + 端口号持久化），二次启动自动聚焦已有窗口并静默退出
- 工具栏窗口模式：不出现在任务栏 / Alt+Tab（对应 Electron `type: 'toolbar'`），配套系统托盘图标（单击恢复窗口、菜单显示/退出；关闭窗口 = 隐藏到托盘）
- 窗口位置、大小、置顶状态、外观颜色、字体、语言自动持久化，重启恢复
- 多显示器下窗口位置越界自动归位到主屏

## 与原版 Electron 版的差异

| 能力 | Electron 版 | Flutter 版 |
| --- | --- | --- |
| 技术栈 | Vue3 + Electron + Vite | Flutter (Dart) |
| 右键菜单 | 独立无边框子窗口 | 主窗口内浮层（钳制在窗口内，超高可滚动） |
| 字体 | 不支持选择 | 支持选择系统字体（跨平台枚举 + 全局应用） |
| 界面语言 | 仅中文 | 中文 / English / 跟随系统，可即时切换 |
| 自动更新 | electron-updater（GitHub Releases） | 自建更新器（GitHub Releases API 检查 → 下载 → 静默安装） |
| 系统通知 | Electron Notification | 应用内轻提示 Toast（跨平台可靠） |
| 单实例锁 | requestSingleInstanceLock | 随机端口占位 + 端口号持久化（纯 Dart，三平台通用） |
| 工具栏窗口 | BrowserWindow `type: 'toolbar'` | 原生窗口样式（Win `WS_EX_TOOLWINDOW` / macOS `LSUIElement` / Linux `_NET_WM_WINDOW_TYPE_TOOLBAR`）+ 系统托盘 |

## 环境要求

- Flutter SDK（3.x 以上，本项目基于 3.47 开发）
- **Windows**：Visual Studio 2022（勾选「使用 C++ 的桌面开发」工作负载）+ 系统设置中开启「开发者模式」（插件构建需要符号链接支持）
- **macOS**：Xcode（在 macOS 上构建）
- **Linux**：GTK 3 开发库、ninja、clang、pkg-config 等（`flutter doctor` 会提示缺失项）

> 国内网络环境建议配置镜像后运行：
>
> ```powershell
> $env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
> $env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
> ```

## 运行

```sh
flutter pub get
flutter run -d windows   # 或 -d macos / -d linux
```

## 打包

### 各平台安装包（GitHub Releases 分发）

| 平台 | 方式 | 命令/脚本 | 产物 |
|---|---|---|---|
| Windows | Inno Setup 6 | `flutter build windows --release` → 用 Inno Setup 编译 `packaging/windows/simple_clock.iss`（或 `iscc packaging\windows\simple_clock.iss`） | `dist\SimpleClock-setup-<版本>.exe` |
| macOS | DMG | 在 macOS 上执行 `bash packaging/macos/build_dmg.sh` | `dist/SimpleClock-<版本>.dmg` |
| Linux | AppImage | 在 Linux 上执行 `bash packaging/linux/build_appimage.sh` | `dist/SimpleClock-<版本>.AppImage` |

> macOS 正式分发前必须完成 **签名 + 公证**（脚本内有 codesign / notarytool / stapler 说明），否则 Gatekeeper 会拦截下载的更新包。Linux 脚本需 `appimagetool`（自动下载）。macOS/Linux 脚本均须在对应平台执行，Windows 上无法验证。

### 自动更新（自建更新器，GitHub Releases）

应用启动数秒后自动检查 `https://api.github.com/repos/Vinkays/SimpleClockFlutter/releases/latest`：

- 发现比当前版本新的 Release → 弹窗询问 → 下载安装包 → 静默安装（Windows `/VERYSILENT`）
- Windows 安装包需以 `.exe` 结尾（Inno Setup 产物即符合）；macOS/Linux 的更新流程在 `update_service.dart` 中按平台扩展（当前仅 Windows 静默安装）

**发布新版本步骤**：

1. 同步版本号：`pubspec.yaml` 的 `version`、`lib/services/update_config.dart` 的 `currentVersion`、`packaging/windows/simple_clock.iss` 的 `MyAppVersion`（当前初始版本 `0.0.1`）
2. 打 tag 并推送（触发下方 GitHub Actions 自动构建发布）或按上表手动打包上传到 GitHub Releases，**tag 形如 `v0.0.2`**（自动更新按 tag 比对版本）
3. 仓库信息已配置在 `lib/services/update_config.dart`（`Vinkays` / `SimpleClockFlutter`），仓库不存在或版本不更新时应用不会提示

### 一键发布（GitHub Actions）

仓库内置 `.github/workflows/release.yml`：**推送 `v*` 格式的 tag 即自动在三平台云端并行构建安装包并上传到该 tag 的 Release**，无需本机安装 Inno Setup，也无需 macOS/Linux 机器。

**首次使用**：

1. 把项目推送到 GitHub 仓库 `Vinkays/SimpleClockFlutter`（新建仓库，名称必须一致）
2. 无需额外配置：Actions 默认开启，tag 触发即运行

**发版流程（以后每次）**：

```sh
# 1. 同步三处版本号（见上），例如都改为 0.0.2
# 2. 提交并打 tag
git add -A && git commit -m "v0.0.2"
git tag v0.0.2
git push origin main --tags
# 3. 到 GitHub → Actions 查看三个任务构建（约 5–10 分钟）
# 4. 完成后到 Releases 页确认附件：
#    SimpleClock-setup-0.0.2.exe / SimpleClock-0.0.2.dmg / SimpleClock-0.0.2.AppImage
```

**注意事项**：

- 自动构建会从 tag 提取版本号（`v0.0.2` → `0.0.2`）注入打包脚本，请确保 tag 与版本号一致
- macOS 产物**未签名**（无 Apple Developer 证书）
- Linux 构建在 ubuntu-latest 上安装 GTK 工具链并自动下载 appimagetool；Windows 构建自动通过 chocolatey 安装 Inno Setup



## 项目结构

```
lib/
├── main.dart                     # 入口：窗口初始化（无边框、尺寸/位置恢复、置顶）
├── app.dart                      # 根组件：全局主题（textTheme 字体跟随、本地化 delegates）
├── controllers/
│   └── app_controller.dart       # 全局状态：外观 / 锁定 / 置顶 / 窗口几何 / 字体 / 语言
├── services/
│   ├── store_service.dart        # 持久化存储（shared_preferences）
│   ├── auto_launch_service.dart  # 开机自启动（launch_at_startup）
│   ├── font_service.dart         # 系统字体枚举（Windows 注册表 / macOS 目录 / Linux fc-list）
│   ├── single_instance_service.dart  # 单实例锁（随机端口 + 端口号持久化）
│   ├── tray_service.dart         # 系统托盘（工具栏窗口的恢复/退出入口）
│   ├── update_service.dart       # 自动更新（GitHub Releases 检查 / 下载 / 启动安装器）
│   ├── update_config.dart        # 更新配置（GitHub 仓库、当前版本号）
│   └── app_strings.dart          # 中英文案（轻量 i18n，无 codegen）
└── ui/
    ├── clock_page.dart           # 主界面：CustomPaint 时钟、拖动/缩放/右键交互、Toast
    └── overlay_panel.dart        # 覆盖面板：右键菜单 + HSV 选色 + 字体选择 + 语言选择

packaging/
├── windows/simple_clock.iss      # Inno Setup 安装脚本（Windows）
├── macos/build_dmg.sh            # DMG 打包脚本（须在 macOS 执行）
└── linux/build_appimage.sh       # AppImage 打包脚本（须在 Linux 执行）

.github/workflows/release.yml    # 三平台自动构建发布（推送 v* tag 触发）
```

## 测试

```sh
flutter test
```

覆盖：时钟界面渲染冒烟测试、外观设置持久化/恢复、字体设置持久化/恢复、
语言设置持久化/恢复、单实例锁（第二个实例检测到已有实例并退出）、
更新器版本比对逻辑、所选字体应用到全局主题，共 7 项。

## 图标

已沿用原项目 favicon（Clock 时钟图标），同步到 Windows / macOS 各尺寸图标资源。

## 许可证

MIT（与原项目一致）
