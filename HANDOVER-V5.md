# CodeIsland 交接文档 V5

## 项目位置
- **源码**: `/tmp/codeisland-ref/`
- **构建**: `cd /tmp/codeisland-ref && swift build`
- **运行**: `pkill -f "CodeIsland" 2>/dev/null; sleep 1; .build/arm64-apple-macosx/debug/CodeIsland &`

## 本次改动总结（V4 → V5）

### Bug 修复

| 文件 | 改动 | 状态 |
|------|------|------|
| `NotchPanelView.swift` | 修复灵动岛点击/hover 冲突 — 在展开/收起计时器回调中添加 surface 状态守卫（`guard appState.surface == .collapsed`/`.sessionList`），防止计时器覆盖用户点击操作 | ✅ |
| `SettingsView.swift` | 删除 4 处未使用代码：`hasNotch` 变量、`PageHeader` 结构体、`statusText()` 方法、`MascotRow.color` 属性 | ✅ |
| `UsageTracker.swift` | 添加 `cachedResults` 字典缓存上次成功的用量数据，provider 返回 nil 时使用缓存并标记 `isStale` | ✅ |
| `UsageTracker.swift` | Cursor SQLite 读取从外部 `/usr/bin/sqlite3` 进程改为原生 `import SQLite3` C API | ✅ |
| `UsageBarView.swift` | 离线/过期服务显示灰色 + `icloud.slash` 图标 | ✅ |
| `Package.swift` | 添加 `libsqlite3` linker 设置 | ✅ |

### 新功能：多服务 OAuth API 查询

| 服务 | 改动 | API |
|------|------|-----|
| Codex | 新增 OAuth API 查询（Keychain "Codex Auth" / `~/.codex/auth.json`），JSONL 作为 fallback | `GET https://chatgpt.com/backend-api/wham/usage` |
| Gemini | 新增 OAuth API 查询（Keychain "gemini-cli-oauth" / `~/.gemini/oauth_creds.json`），支持 token 自动刷新，本地 logs 作为 fallback | `POST cloudcode-pa.googleapis.com/v1internal:loadCodeAssist` → `retrieveUserQuota` |
| Cursor | 改用 `usage-summary` API（更完整），直接从 SQLite 读 `cursorAuth/userId` 而非从 JWT 解码 | `GET https://cursor.com/api/usage-summary` |

### 新功能：缓存命中率追踪

- 在 Claude API Key 模式下追踪 `cache_read_input_tokens` 占比
- `ServiceUsageData` 新增 `cacheHitRate`、`cacheHitColor`、`cacheHitWarning` 属性
- UI 显示 `Cache XX%`：绿色 ≥80%、黄色 60-80%、红色 <60%（暗示假 API Key）
- 至少 3 条消息后才计算（避免样本不足）

### KeychainHelper 扩展

新增方法：
- `readCodexOAuthToken()` — 从 Keychain 或 `~/.codex/auth.json` 读取（仅 `chatgpt` OAuth 模式）
- `readGeminiOAuthToken()` — 从 Keychain 或 `~/.gemini/oauth_creds.json` 读取
- `refreshGeminiToken()` — 使用 Google OAuth refresh_token 刷新 access_token

---

## 参考资料（已分析，供下次实现用）

### CC-Switch 计费架构
- **代理层统计**：拦截 API 请求，解析 token 用量，SQLite 持久化
- **模块**：`parser.rs`（多格式响应解析）、`calculator.rs`（高精度成本计算）、`logger.rs`（SQLite 记录）
- **OAuth 配额查询**：Claude `api.anthropic.com/api/oauth/usage`、Codex `chatgpt.com/backend-api/wham/usage`、Gemini `cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`

### Forge Tools 发现
- **Cursor 新 API**: `cursor.com/api/usage-summary`（返回 `totalPercentUsed`、`autoPercentUsed`、`apiPercentUsed`、billing cycle 等完整信息）
- **Cursor 详细事件**: `cursor.com/api/dashboard/get-aggregated-usage-events`
- **订阅信息**: `api2.cursor.sh/auth/full_stripe_profile`
- **Token 刷新**: `api2.cursor.sh/oauth/token`（client ID: `KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB`）
- **Windsurf 额度字段**: `dailyQuotaRemainingPercent`、`weeklyQuotaRemainingPercent`、`promptCredits`、`flowCredits`、从 `state.vscdb` 读取

---

## 待实施计划

### Phase 3: 环境安全检测（高优先级）

基于 Claude Code 封号机制报告（`/Users/wei/Desktop/Claude Code 封号机制深度探查报告.pdf`）和 cc-gateway（`https://github.com/motiful/cc-gateway`）。

#### 新增文件
| 文件 | 说明 |
|------|------|
| `Sources/CodeIsland/EnvironmentChecker.swift` | 环境安全检测核心 |

#### 检测维度

| 类别 | 检测项 | 风险等级 | 实现方式 |
|------|--------|----------|----------|
| 网络 | IP 地区 | 高 | `ipinfo.io/json` 或 `ip-api.com/json` API |
| 网络 | 数据中心/VPN IP | 高 | 检查 ASN/ISP 是否为已知 DC 提供商 |
| 网络 | 时区与 IP 地区匹配 | 中 | `TimeZone.current.identifier` vs IP geoIP |
| 身份 | DeviceID 存在性 | 中 | 检查 `~/.claude/config.json` 的 `userID` 字段 |
| 身份 | 多账号指纹 | 高 | 检查 `~/.claude/config.json` 中 accountUuid 是否频繁变化 |
| 环境 | CI/CD 环境变量 | 高 | 检查 `GITHUB_ACTIONS`、`GITLAB_CI`、`CI` 等 |
| 环境 | Docker/容器 | 中 | 检查 `/.dockerenv`、`KUBERNETES_SERVICE_HOST` |
| 环境 | SSH 远程 | 低 | 检查 `SSH_CONNECTION`、`SSH_TTY` |
| 环境 | WSL 环境 | 低 | 检查 `WSL_DISTRO_NAME` |
| 遥测 | 遥测禁用状态 | 信息 | 检查 `DISABLE_TELEMETRY`、`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` |
| 遥测 | 失败缓存积压 | 低 | 检查 `~/.claude/telemetry/` 目录大小 |
| 凭据 | Keychain vs 文件 | 中 | 检查 `.credentials.json` 是否存在（Keychain 不可用时降级） |
| 保护 | Bedrock/Vertex 模式 | 安全 | 检查 `CLAUDE_CODE_USE_BEDROCK`/`VERTEX` |
| 客户端 | 版本过旧 | 低-中 | 检查 Claude Code CLI 版本 |

#### UI 入口
- 右翼展开状态：在音量/汉堡菜单旁添加 `shield.checkered` 图标按钮
- 新 surface: `.environmentCheck`
- 面板显示：分类卡片式检测结果（绿✅/黄⚠️/红❌），底部一键检测按钮

### Phase 4+: 见 PLAN.md

---

## 已知问题

1. **Cursor `past_due` 订阅** — 当前测试账号 `stripeSubscriptionStatus` 为 `past_due`，API 可用但数据可能不完整
2. **Codex JSONL 0 用量** — 如果本地没有最近 7 天的 Codex 会话文件，显示 0
3. **Gemini OAuth token 过期** — access_token 仅 ~1h 有效，refresh_token 刷新可能失败时回退到本地 logs
4. **灵动岛点击响应** — `.onTapGesture` 与 hover 交互冲突已修复，但极端快速操作可能仍有边缘情况

## 新增依赖

- `import SQLite3`（系统库，linkerSettings 中链接 `libsqlite3`）
- 无新增外部 SPM 包
