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

- **状态**：已完成（0.0.12）
- **背景**：当前时钟固定 24 小时制（`clock_page.dart` 用 `now.hour` 直接取 0-23）；用户系统若为 12 小时制则显示习惯不一致。Flutter 无直接 API 读取系统 12/24 设置，需平台原生检测
- **方案**（已实施）：
  - [x] 平台检测：Windows 注册表 `HKCU\Control Panel\International\sTimeFormat`（含 `h` = 12 小时制，`H` = 24 小时制）；macOS `NSUserDefaults` 的 `AppleICUForce24HourTime` / `AppleICUForce12HourTime`（均无则读取 `AppleICUDateFormatStrings`）；Linux GNOME dconf `clock-format`（`12h`/`24h`）+ `LC_TIME` 常用 12 小时制区域匹配
  - [x] 设置项：「跟随系统 / 12 小时制 / 24 小时制」三选，默认跟随系统，检测失败回落 24 小时制（保持既有显示习惯）
  - [x] `clock_page.dart` 显示逻辑按选择格式化：12 小时制小时转 1-12 并在秒数后显示 AM/PM（与数字同字号、同拉伸）；24 小时制不显示 AM/PM
- **涉及文件**：`lib/ui/clock_page.dart`、`lib/controllers/app_controller.dart`、`lib/services/time_format_service.dart`（新增）、`lib/services/store_service.dart`、`lib/ui/widgets/scaled_clock.dart`、`lib/ui/state/clock_ticker.dart`、`lib/ui/panels/time_format_panel.dart`（新增）、`lib/ui/panels/menu_panel.dart`、`lib/ui/state/overlay_controller.dart`、`lib/services/app_strings.dart`
