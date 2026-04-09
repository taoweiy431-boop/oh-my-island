# CodeIsland 交接文档 V4

## 项目位置
- **源码**: `/tmp/codeisland-ref/`
- **构建**: `cd /tmp/codeisland-ref && swift build`
- **运行**: `pkill -f "CodeIsland" 2>/dev/null; sleep 1; .build/arm64-apple-macosx/debug/CodeIsland &`

## 本次改动总结（V3 → V4）

### Phase 2: 多服务用量/配额监控系统

#### 新增文件

| 文件 | 行数 | 说明 |
|------|------|------|
| `Sources/CodeIsland/UsageTracker.swift` | ~600 | 多服务用量追踪核心 — AIService 枚举、UsageProvider 协议、6 个 Provider 实现、告警通知 |
| `Sources/CodeIsland/UsageBarView.swift` | ~330 | 用量 UI 组件 — UsageMiniBar (收起)、UsagePanelView (展开，含内嵌设置)、多服务 ServiceRow |

#### 修改文件

| 文件 | 改动 |
|------|------|
| `IslandSurface.swift` | 新增 `.usagePanel` 和 `.settingsPanel` case |
| `NotchPanelView.swift` | +内嵌设置界面 `NotchSettingsView`（全功能）、+用量面板渲染、+右翼微型进度条、+展开右翼用量/汉堡菜单按钮、+hover 逻辑处理新 surface |
| `AppDelegate.swift` | 启动 `UsageTracker.shared.start()`，退出时 `stop()` |
| `Settings.swift` | 新增 `usageWarningThreshold`、`claudeApiKeyFiveHourLimit`、`claudeApiKeyWeeklyLimit` 设置项 |
| `SettingsView.swift` | 新增 `.usage` 页面到侧栏 + `UsageSettingsPage` 视图 |

### 开屏动画优化

| 文件 | 改动 |
|------|------|
| `OnboardingView.swift` | 欢迎页动画重设计、Agent 吸收卡片重绘为真实应用窗口风格、Get Started 按钮改为 Claude 橙色 |

---

## 多服务用量监控详解

### 支持的 6 个 AI 服务

| 服务 | 数据源 | 认证方式 | 窗口 |
|------|--------|----------|------|
| Claude Code | Anthropic OAuth API (`/api/oauth/usage`) | Keychain `Claude Code-credentials` | 5h + 7d |
| Claude Code (回退) | 本地 JSONL `~/.claude/projects/**/*.jsonl` | 无需认证 | 5h + 7d (token 统计) |
| OpenAI Codex | 本地 `~/.codex/sessions/**/*.jsonl` | 无需认证 | 5h + 7d |
| Google Gemini | 本地 `~/.gemini/tmp/**/logs.json` | 无需认证 | 1d |
| GitHub Copilot | GitHub API (`/copilot_internal/user`) | `gh auth token` | Mo |
| Cursor | SQLite `state.vscdb` + Cursor API (`/api/usage`) | JWT from SQLite | Mo |
| Z.ai | Z.ai API (`/api/monitor/usage/quota/limit`) | Keychain `com.codeisland.apikeys` / account `zai` | 5h + MCP |

### Claude Code JSONL 回退模式

当 OAuth token 不存在时，自动扫描 `~/.claude/projects/` 下的 JSONL 文件：
- 提取 `type: "assistant"` 消息的 `usage` 字段
- 统计 `input_tokens + output_tokens + cache_creation_input_tokens`
- 在 5h / 7d 滚动窗口内累加
- 使用可配置限额（默认 5h=5M, 7d=50M tokens）
- 显示 "API Key" plan 标签

### 数据模型

```swift
enum AIService: String, CaseIterable { claude, codex, gemini, copilot, cursor, zai }
struct UsageMetric { used, total, unit(.percent/.tokens/.requests), resetTime }
struct ServiceUsageData { service, primaryUsage, secondaryUsage, planName, isAvailable }
protocol UsageProvider { isConfigured() -> Bool; fetchUsage() async -> ServiceUsageData? }
```

### UI 入口

- **收起状态**: 右翼微型进度条 (30x3px)，点击打开用量面板
- **展开状态**: 右翼图标按钮 (chart.bar.fill)，点击切换用量面板
- **用量面板**: 多服务列表 + 各服务主/次窗口 + 百分比 + 重置倒计时 + 内嵌设置（齿轮图标展开）
- **告警**: 80%+黄色脉冲边框, 95%+红色脉冲 + macOS 通知

### 内嵌设置面板 (settingsPanel)

点击展开状态右上角 **三条横线** 汉堡菜单按钮，在灵动岛内直接显示全部设置：

| 区域 | 设置项 |
|------|--------|
| 通用 | 开机自启、语言 |
| 行为 | 全屏隐藏、无会话隐藏、智能抑制、鼠标离开收起、会话超时、工具历史 |
| 外观 | 最大会话数、字体大小、AI回复行数、Agent详情、吉祥物速度 |
| 音效 | 总开关、音量、7个独立事件开关 |
| 用量告警 | 阈值切换 (Off/50/70/80/90/95%)、API Key 限额 |
| Hooks | 各 CLI 安装状态 (8个: Claude/Codex/Gemini/Cursor/Qoder/Factory/CodeBuddy/OpenCode) + 重装/卸载 |
| 操作 | 检查更新、退出 |

---

## 开屏动画改动

### 欢迎页 (Step 0)

1. **模糊光晕背景** — RadialGradient (Claude橙→紫→透明, 600px, blur 60px)
2. **灵动岛缓慢出现** — 0.8s 延迟 + 1.0s easeInOut 淡入
3. **彩虹光晕** — 4s 周期旋转，1.5s 渐显
4. **标语** — monospaced 字体，2.2s 后淡入
5. **按钮** — Claude 橙色胶囊 + 白字 + 橙色阴影光晕，2.8s 后淡入
6. **音效** — `onboarding-ceremony.wav` 同步播放

### Agent 吸收卡片 (Step 1)

3 张卡片重新设计为真实应用窗口风格（带 macOS 三色窗口点）：

| 卡片 | 风格 | 内容 |
|------|------|------|
| Claude Code | 终端风格 | 🟠 Claude Code v2.1 + `> add dark mode` + Read/Edit/Clauding… 工具调用 |
| OpenAI Codex | 聊天风格 | ⚪ OpenAI Codex + 蓝色引用条 + 对话回复 + 文件编辑状态 |
| Cursor | IDE 风格 | 🟣 Cursor + GPT-6.4 + 左侧文件树 + 右侧代码编辑器 |

---

## 待实施计划

### Phase 3: 终端精准跳转（高优先级）
- cmux 深度集成：`ps -Ax` → PID env vars → `cmux send`
- 新增 WezTerm/Kaku 支持

### Phase 4-7: 见 PLAN.md

---

## 已知问题

1. **灵动岛点击响应** — `.onTapGesture` 与 hover 交互可能冲突
2. **buddy 在 API Key 模式不可用** — Claude Code 的 `/buddy` 命令在 API Key 模式下显示 "unavailable"
3. **开屏壁纸** — `onboarding-wallpaper.jpg` 可能不在 Bundle 中，fallback 到渐变
4. **SettingsView hasNotch 警告** — 未使用变量警告
5. **用量 API 需要网络** — OAuth API 调用需要网络连接，无网时显示空
6. **Cursor SQLite 读取** — 使用 sqlite3 命令行工具，可能需要完整磁盘访问权限

## 新增依赖

- UserNotifications framework（用量告警通知）
- Security framework（Keychain 读取，Z.ai API key）
- 无新增外部 SPM 包
