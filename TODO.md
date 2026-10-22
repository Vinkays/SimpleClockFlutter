# 待办清单

## 更新弹窗显示本次更新内容（latest.json notes + changelog）

- **状态**：待办，等待 Flutter 多窗口/富文本展示能力成熟后再评估
- **背景**：参考 BongoCat 的 latest.json 结构（`version` + `notes` + `platforms`），其 `notes` 字段携带当前版本 changelog（内容即 GitHub Release body），且 latest.json 同时作为该版本 release 的附件上传
- **方案**：
  - [ ] `release.yml` 的 `update-latest-json` job：截取 CHANGELOG.md 最新版本条目（`## [X.Y.Z]` 至下一个 `## [` 之间）→ 写入 `latest.json` 的 `notes` 字段；同时设为 Release body；并上传一份 latest.json 到该 release 附件（客户端检查仍走仓库根目录 raw CDN，不限流，不引入 GitHub API 限流）
  - [ ] 客户端 `update_service.dart` 解析 `notes`
  - [ ] `clock_page.dart` 更新弹窗内新增可滚动 changelog 区域，替代现在仅一句"发现新版本 vX.X.X"
- **触发条件**：Flutter 更新多窗口应用功能后重新评估展示方案（版本更新内容过长时，现阶段单弹窗展示效果不佳）
- **涉及文件**：`CHANGELOG.md`、`latest.json`、`.github/workflows/release.yml`、`lib/services/update_service.dart`、`lib/ui/clock_page.dart`

## 时钟显示跟随系统 12/24 小时制

- **状态**：待办，评估后再决定是否实施
- **背景**：当前时钟固定 24 小时制（`clock_page.dart` 用 `now.hour` 直接取 0-23）；用户系统若为 12 小时制则显示习惯不一致。Flutter 无直接 API 读取系统 12/24 设置，需平台原生检测
- **方案**：
  - [ ] 平台检测：Windows 注册表 `HKCU\Control Panel\International\sTimeFormat`（含 `h` = 12 小时制，`H` = 24 小时制）；macOS `NSUserDefaults` 的 `AppleICUForce24HourTime` / `AppleICUForce12HourTime`（均无则跟随 locale）；Linux locale `LC_TIME` + 桌面环境设置（GNOME dconf `clock-format`）
  - [ ] 设置项：「跟随系统 / 12 小时制 / 24 小时制」三选，默认跟随系统，检测失败回落固定格式
  - [ ] `clock_page.dart` 显示逻辑按选择格式化（12 小时制补 AM/PM）
- **触发条件**：评估后再定（用户对 UI 变化敏感，避免强制改变现有用户习惯；近似方案 `Platform.localeName` + 地区惯例映射不准确，不采用）
- **涉及文件**：`lib/ui/clock_page.dart`、`lib/controllers/app_controller.dart`（设置项）、Windows/macOS/Linux 原生读取
