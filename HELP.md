# 构建

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

## 测试

```sh
flutter test
```

## 更新版本号

版本号共 5 处：`pubspec.yaml` 的 `version`、`lib/services/update_config.dart` 的 `currentVersion`、`packaging/windows/simple_clock.iss` 的 `MyAppVersion`、`packaging/macos/build_dmg.sh` 的 `VERSION`、`packaging/linux/build_appimage.sh` 的 `VERSION`。

**`latest.json` 不要手动改**，它由 GitHub Actions 自动生成。`release.yml` 末尾的 `update-latest-json` job 会在三平台产物全部就绪后自动重写它并 push 回 main。手动改会造成"用户先收到更新提示、安装包还未就绪"的窗口期。

### 一键脚本更新版本 

按发布者平台选择更新方式：

**Windows 发布者（推荐）**——一键脚本：

```powershell
powershell -ExecutionPolicy Bypass -File tools\set_version.ps1 版本号（例如 0.0.2，下同）
```


**macOS / Linux 发布者**——两种方式任选：

方式一：安装 PowerShell Core（pwsh）后运行**同一个脚本**：

```sh
brew install powershell     # macOS
snap install powershell     # Linux
pwsh tools/set_version.ps1 版本号
```

方式二：**只改 2 处**，其余 3 处由 GitHub Actions 从 tag 自动注入：

- `pubspec.yaml` 的 `version`
- `lib/services/update_config.dart` 的 `currentVersion`

（`simple_clock.iss` / `build_dmg.sh` / `build_appimage.sh` 的版本号在 `release.yml` 构建时由 tag 自动替换，本地无需改动。）

## 打包

### 各平台安装包（GitHub Releases 分发）

| 平台 | 方式 | 命令/脚本 | 产物 |
|---|---|---|---|
| Windows | Inno Setup 6 | `flutter build windows --release` → 用 Inno Setup 编译 `packaging/windows/simple_clock.iss`（或 `iscc packaging\windows\simple_clock.iss`）（packaging/windows/simple_clock.iss里打包的资源来自build生成的build\windows\x64\runner\Release\） | `dist\SimpleClock-setup-<版本>.exe` |
| macOS | DMG | 在 macOS 上执行 `bash packaging/macos/build_dmg.sh` | `dist/SimpleClock-<版本>.dmg` |
| Linux | AppImage | 在 Linux 上执行 `bash packaging/linux/build_appimage.sh` | `dist/SimpleClock-<版本>.AppImage` |

> macOS 正式分发前必须完成 **签名 + 公证**（脚本内有 codesign / notarytool / stapler 说明），否则 Gatekeeper 会拦截下载的更新包。Linux 脚本需 `appimagetool`（自动下载）。macOS/Linux 脚本均须在对应平台执行，Windows 上无法验证。

### 自动更新（自建更新器，GitHub Releases）

应用启动数秒后自动优先检查raw `latest.json`（不限流），API `https://api.github.com/repos/Vinkays/SimpleClockFlutter/releases/latest`（每日限流）兜底：

- 发现比当前版本新的 Release → 弹窗询问 → 下载安装包 → 静默安装（Windows `/VERYSILENT`）
- Windows 安装包需以 `.exe` 结尾（Inno Setup 产物即符合）；macOS/Linux 的更新流程在 `update_service.dart` 中按平台扩展

**发布新版本步骤**：



### 一键发布（GitHub Actions）

仓库内置 `.github/workflows/release.yml`：**推送 `v*` 格式的 tag 即自动在三平台云端并行构建安装包并上传到该 tag 的 Release**，无需本机安装 Inno Setup，也无需 macOS/Linux 机器。


**发版流程（以后每次）**：

```sh
# 1. 按上节更新版本号（Windows 用脚本 / macOS、Linux 用 pwsh 或只改两处），例如 0.0.2
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

