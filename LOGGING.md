# LOGGING.md — 应用日志说明

> 本文档解释应用「调试日志」功能产生的日志文件里，每一行各字段的含义，
> 以及如何根据日志排查「收不到更新提示」「下载失败」等问题。
> 更新代码埋点时，请同步维护本文档。

## 一、如何开启与查看

- **开启**：右键菜单 →「调试日志」（尾部显示 开/关）。开关持久化，重启后保持。
- **查看**：右键菜单 →「关于我们」→「打开日志文件」，用系统默认编辑器打开
  （Windows 记事本 / macOS `open` / Linux `xdg-open`）。
- **日志文件位置**（开关开启后，首次写入时创建）：

| 平台 | 路径 |
|---|---|
| Windows | `%APPDATA%\SimpleClock\logs\simple_clock.log` |
| macOS | `~/Library/Application Support/SimpleClock/logs/simple_clock.log` |
| Linux | `~/.local/share/SimpleClock/logs/simple_clock.log` |

- 超过 512 KB 时轮转为 `simple_clock.log.1`（最多保留两份）；
  打开日志文件时若超过 2000 行会自动截断，只保留**最新（文件顶部）**2000 行。

## 二、日志格式

```
<UTC ISO 8601 时间戳>  <事件>
```

例如：

```
2026-10-22T14:28:28.992341  update.check raw ok update-available tag=v0.0.10
```

> - **新日志写入文件最前**（最新一条在最上面，打开即见）。
> - 注意：时间戳是 **UTC**，不是本地时间（北京时间 = UTC + 8 小时）。
>   例如 `14:28:28` UTC 对应北京时间 `22:28:28`。

## 三、事件含义表

### 3.1 更新检查（update.check）

| 事件 | 含义 | 后续行为 |
|---|---|---|
| `update.check skip: repo not configured` | 未配置 GitHub 仓库（owner/repo 缺失或占位符） | 不发起检查 |
| `update.check start (current=…, raw=…)` | 一次检查开始；current=本地版本 | 依次尝试 raw → jsdelivr → API |
| `update.check trigger (retryAttempt=N)` | 检查触发：启动 4s / 每小时心跳 / 退避重试，N=已重试次数 | — |
| `update.check manual (cooldown cleared)` | 用户点了「检查更新」（已清冷却） | 立即检查 |
| `update.check raw/jsdelivr/api ok update-available tag=vX.X.X` | 该通道请求成功，远端版本高于本地，**发现新版本** | 进入冷却检查 → 弹窗 |
| `update.check raw/jsdelivr/api ok up-to-date` | 该通道请求成功，已是最新 | 静默 |
| `update.check raw/jsdelivr/api http 404` | 通道返回 404（latest.json 不存在） | 视为内容问题，**不重试**、不降级 |
| `update.check raw/jsdelivr/api http <5xx>` | 通道返回服务端错误（500/502/503…） | **可重试**，换下一通道或退避 |
| `update.check raw/jsdelivr/api bad-json` | JSON 解析失败 | 内容问题，不重试、不降级 |
| `update.check raw/jsdelivr/api empty-version` | JSON 里 version 字段为空 | 内容问题，不重试、不降级 |
| `update.check raw/jsdelivr/api no-assets` | JSON 里 assets 为空（无安装包链接） | 内容问题，不重试、不降级 |
| `update.check raw/jsdelivr/api socket-error / http-exception / timeout / unknown-error` | 网络不可达 / 连接异常 / 超时 | **可重试**：raw/jsdelivr 失败则降级下一通道；均失败按退避重试 |
| `update.check <channel> decided state=… tag=…` | 该通道结果已"定论"（发现更新 / 已最新 / 内容问题），不再降级 | 按 state 处理 |
| `update.check fallback -> github api` | raw 与 jsdelivr 均未定论（网络类失败），降级到 GitHub API | 请求 GitHub API |
| `update.check snoozed tag=vX.X.X until=…` | **冷却命中**：该版本点过「稍后」且未到期 | 本次不提示 |
| `update.check show-prompt tag=vX.X.X` | 通过冷却检查，准备弹出「发现新版本」 | 撑大窗口 + 弹窗 |
| `update.check retry-scheduled attempt=N delay=Xmin` | 网络类失败，安排退避重试（3min → 15min → 30min） | N 次后耗尽，由每小时心跳接管 |
| `update.check up-to-date` | 已是最新版本 | 静默 |
| `update.check http-error (no retry)` | 内容问题（4xx / 非法内容），重试无意义 | 静默，等下次心跳 |
| `update.check not-configured` | 仓库未配置 | 静默 |

### 3.2 冷却（update.snooze）

| 事件 | 含义 |
|---|---|
| `update.snooze tag=vX.X.X hours=N until=…` | 记录「稍后」冷却：该版本 N 小时内不再提示（until 为到期时刻 UTC） |
| `update.later clicked` | 用户点了「稍后更新」 |
| `update.now clicked tag=vX.X.X` | 用户点了「立即更新」 |

### 3.3 下载（update.download）

| 事件 | 含义 |
|---|---|
| `update.download start url=…` | 开始下载安装包（url 为远端地址） |
| `update.download ok bytes=N -> 路径` | 下载完成，N=字节数，路径为落盘位置（系统临时目录） |
| `update.download fail http <code>` | 下载失败：服务端返回非 200 |
| `update.download fail unknown-error` | 下载失败：网络异常等 |
| `update.download cancelled by user` | 用户在下载过程中点了取消（等同「稍后」，进入冷却） |

### 3.4 安装（update.launch）

| 事件 | 含义 |
|---|---|
| `update.launch start platform=… installer=…` | 开始启动安装器（platform=windows/macos/linux） |
| `update.launch ok (windows/macos/linux)` | 安装进程已成功启动（应用随即退出） |
| `update.launch unsupported-platform` | 当前平台无安装支持 |
| `update.launch fail: <原因>` | 启动安装器失败 |

### 3.5 调度生命周期（update.schedule）

| 事件 | 含义 |
|---|---|
| `update.schedule start (heartbeat 1h)` | 更新检查调度启动：4s 后首次检查 + 每小时心跳 |
| `update.schedule disposed` | 调度释放（应用退出） |

## 四、通道与重试语义（速记）

- **通道优先级**：`raw.githubusercontent.com`（首选，实时）→ `cdn.jsdelivr.net`（兜底 1，缓存约 12h）→ `api.github.com`（兜底 2，匿名限流 60 次/小时）。
- **会继续降级/重试的**（网络类）：`socket-error`、`http-exception`、`timeout`、`unknown-error`、`http 5xx`。
- **定论且不降级/不重试的**（内容类）：`http 404`、`bad-json`、`empty-version`、`no-assets`。

## 五、快速诊断指引

### 场景 1：用户（尤其 macOS/Linux）反馈收不到更新提示

让用户开启「调试日志」→ 手动点一次「检查更新」→ 把日志文件发给你，重点看：

1. `update.check start (current=…)` —— 本地版本号是多少（太低/为 0.0.0 说明打包或配置问题）。
2. `raw` / `jsdelivr` / `api` 三通道各自是 `ok` 还是各种 `error` —— 判断是哪类网络问题。
3. `update-available` vs `up-to-date` —— 远端是否确实比本地新。
4. `snoozed` —— 是否被冷却拦截（用户之前点过「稍后」）。
5. `show-prompt` —— 是否已进入弹窗分支。

### 场景 2：点击「立即更新」后无反应

1. `update.now clicked` —— 是否走到了立即更新。
2. `update.download start` / `ok` / `fail` —— 下载是否成功。
3. `update.launch start` / `ok` / `fail` —— 安装器是否成功启动。
