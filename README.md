<div align="center">
  <img src="assets/1.jpg" alt="snapshot" />
</div>

<div align="center">
  <div>
    <a href="https://github.com/Vinkays/SimpleClockFlutter/releases"><img alt="Windows" src="https://img.shields.io/badge/-Windows-blue?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB0PSIxNzI2MzA1OTcxMDA2IiBjbGFzcz0iaWNvbiIgdmlld0JveD0iMCAwIDEwMjQgMTAyNCIgdmVyc2lvbj0iMS4xIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHAtaWQ9IjE1NDgiIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4Ij48cGF0aCBkPSJNNTI3LjI3NTU1MTYxIDk2Ljk3MTAzMDEzdjM3My45OTIxMDY2N2g0OTQuNTEzNjE5NzVWMTUuMDI2NzU3NTN6TTUyNy4yNzU1NTE2MSA5MjguMzIzNTA4MTVsNDk0LjUxMzYxOTc1IDgwLjUyMDI4MDQ5di00NTUuNjc3NDcxNjFoLTQ5NC41MTM2MTk3NXpNNC42NzA0NTEzNiA0NzAuODMzNjgyOTdINDIyLjY3Njg1OTI1VjExMC41NjM2ODE5N2wtNDE4LjAwNjQwNzg5IDY5LjI1Nzc5NzUzek00LjY3MDQ1MTM2IDg0Ni43Njc1OTcwM0w0MjIuNjc2ODU5MjUgOTE0Ljg2MDMxMDEzVjU1My4xNjYzMTcwM0g0LjY3MDQ1MTM2eiIgcC1pZD0iMTU0OSIgZmlsbD0iI2ZmZmZmZiI+PC9wYXRoPjwvc3ZnPg==" />
    </a>
    <a href="https://github.com/Vinkays/SimpleClockFlutter/releases"><img alt="macOS" src="https://img.shields.io/badge/-macOS-black?style=flat-square&logo=apple&logoColor=white" /></a>
     <a href="https://github.com/Vinkays/SimpleClockFlutter/releases"><img alt="Linux" src="https://img.shields.io/badge/-Linux-blue?style=flat-square&logo=linux&logoColor=white" /></a>
  </div>

  <div>
   <a href="/LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"/></a>
   <a href="https://github.com/Vinkays/SimpleClockFlutter/releases"><img src="https://img.shields.io/github/v/release/Vinkays/SimpleClockFlutter?include_prereleases"/></a>
  </div>
</div>

SimpleClockFlutter-简易时钟(Flutter版) 是一款面向Windows、macOS、Linux的桌面简易时钟工具，它简洁的设计和实用的功能，为用户提供方便的时钟查看体验。使用 Flutter 重写 Electron + Vue3 项目 [SimpleClock](https://github.com/Vinkays/SimpleClock)

## 功能

- 无边框时钟窗口，实时显示 HH:MM:SS
- 时间随窗口大小缩放
- 左键拖动窗口
- 右键菜单（窗口内浮层，窗口过小时自动临时撑大，关闭后恢复）：
  - 文字颜色 / 背景色（HSV 颜色选择器 + 预设色块）
  - 字体：列出**本机已安装字体**，带搜索框与实时预览
  - 语言：跟随系统 / 中文 / English
  - 锁定（禁止拖动与缩放）/ 解除锁定
  - 置顶 / 移除置顶
  - 设置 / 移除开机自启动
  - 退出程序
- 操作结果通过应用内 Toast 轻提示（Toast 显示时自动撑大窗口、文字自适应，任何窗口尺寸都完整可见）
- 窗口位置、大小、置顶状态、外观颜色、字体、语言自动持久化，重启恢复
- 多显示器下窗口位置越界自动归位到主屏

## 与原版 Electron 版的差异

| 能力 | Electron 版 | Flutter 版 |
| --- | --- | --- |
| 技术栈 | Vue3 + Electron + Vite | Flutter (Dart) |
| 右键菜单 | 独立无边框子窗口 | 主窗口内浮层（钳制在窗口内） |
| 字体 | 不支持选择 | 支持选择系统字体（跨平台枚举 + 全局应用） |
| 界面语言 | 仅中文 | 中文 / English / 跟随系统，可即时切换 |
| 自动更新 | electron-updater（GitHub Releases） | 自建更新器（GitHub Releases API 检查 → 下载 → 静默安装） |
| 系统通知 | Electron Notification | 应用内轻提示 Toast（跨平台可靠） |
| 单实例锁 | requestSingleInstanceLock | 随机端口占位 + 端口号持久化（纯 Dart，三平台通用） |


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
├── windows/simple_clock.iss      # Inno Setup 安装脚本
├── macos/build_dmg.sh            # DMG 打包脚本
└── linux/build_appimage.sh       # AppImage 打包脚本
```
## License
SimpleClockFlutter is licensed under the MIT License - see the [LICENSE](/LICENSE) file for details