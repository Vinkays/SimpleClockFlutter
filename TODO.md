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
