# CodeIsland 交接文档 V3

## 项目位置
- **源码**: `/tmp/codeisland-ref/`
- **构建**: `cd /tmp/codeisland-ref && swift build`
- **运行**: `pkill -f "CodeIsland" 2>/dev/null; sleep 1; .build/arm64-apple-macosx/debug/CodeIsland &`

## 本次改动总结（V2 → V3）

### 新增文件

| 文件 | 行数 | 说明 |
|------|------|------|
| `Sources/CodeIsland/BuddyService.swift` | ~200 | Buddy 数据读取 + WyHash/Mulberry32 hash 算法，精确匹配 Claude Code |
| `Sources/CodeIsland/BuddyAsciiArt.swift` | ~260 | 18 种 species 的 ASCII art 帧动画定义（每种 2 帧） |
| `Sources/CodeIsland/BuddyCardView.swift` | ~160 | Buddy 卡片 UI — ASCII sprite + stats bars + rarity 星级 |
| `Sources/CodeIsland/WyHash.swift` | ~105 | wyhash v4 完整实现，精确匹配 Bun.hash() 输出（搬运自 xmqywx/CodeIsland） |
| `PLAN.md` | ~280 | 7 阶段功能升级计划 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `IslandSurface.swift` | 新增 `.buddyCard` case |
| `NotchPanelView.swift` | 新增 buddy 卡片渲染 + Claude Logo 点击打开 buddy + MascotView 点击打开 buddy + hover 逻辑处理 buddyCard |
| `AppDelegate.swift` | 启动时调用 `BuddyService.shared.load()` |
| `OnboardingView.swift` | 5 项开屏动画优化（见下方详细） |

### 开屏动画优化（5 项）

1. **退出动画升级** — 内容缩小到 0.15 倍 + 上移到 notch 位置，光晕消散 + 背景渐出（替代简单的淡出）
2. **RainbowGlow 重写** — 从 12 个 Canvas 椭圆改为双层 `AngularGradient + Capsule.stroke`（橙→金→白→青→蓝→紫→橙）
3. **buttonAppeared 绑定** — "Get Started" 按钮正确绑定了 opacity + offset 动画
4. **壁纸 fallback** — 加载失败时显示深紫→深蓝→黑的 `LinearGradient` 背景
5. **吸收节奏调整** — 卡片间隔从 0.6s → 0.8s，整体时间线延长 0.6s

## Buddy 系统实现细节

### 数据流
1. 读取 `~/.claude.json` 的 `companion` 字段（name + personality）
2. 获取 userId（优先 `oauthAccount.accountUuid`，其次 `userID`，fallback `"anon"`）
3. 检测 salt（缓存文件 `~/.claude/.codeisland-salt` → 默认 `"friend-2026-401"`）
4. `WyHash.hash(userId + salt)` → `Mulberry32(seed)` → 按顺序 roll：
   - rarity (60/25/10/4/1 权重) → species (18种) → eye (6种) → hat (8种, common=none) → shiny (1%) → stats (peak/dump/normal)
5. 如果无 `companion` 数据，用 `NSUserName()` 生成默认 buddy

### Stats 范围
- 原始值 0-100（不是 0-10）
- 显示进度条时 `raw * 10 / 100` 缩放到 10 格

### 入口
- **收起状态**: 点击左翼 MascotView
- **展开状态**: 点击左上角 ClaudeLogoCompact

## 竞品分析

### AI 编程 Notch 项目

| 项目 | GitHub | 特色 | 开屏动画 |
|------|--------|------|---------|
| Vibe Island | vibeisland.app (闭源) | 最成熟商业品，6+ AI工具，13种终端 | 有（电影级） |
| Open Vibe Island | Octane0411/open-vibe-island | Vibe Island 开源替代，97 stars | 无 |
| Claude Island | farouqaldori/claude-island | 开山鼻祖，极简风 | 无 |
| CodeIsland (xmqywx) | xmqywx/CodeIsland | Buddy + iPhone配套 + cmux深度集成 | 无 |
| AgentNotch | AppGram/agentnotch | Token/成本统计 | 无 |
| Notchi | sk-ruban/notchi | 情感分析吉祥物 | 无 |
| Treland | mindfold-ai/Treland | Git分支 + ctx N% | 无 |

### 通用 Notch 项目

| 项目 | 特色 |
|------|------|
| Atoll | 1.6k stars，功能最全，媒体/系统监控/剪贴板 |
| Boring.Notch | 有简单欢迎动画 |
| Aura | 集成本地 AI (Ollama) |
| PikoChan | 刘海里的 AI 助手 |

### Buddy 相关工具

| 工具 | 功能 |
|------|------|
| any-buddy | 暴力搜索 salt + 二进制 patch，自选宠物外观 |
| claudecode-buddy-crack | 类似 any-buddy |
| mashang-claude-code | 还原源码二次开发，开发者模式可开启被门控的 buddy |

### 会话管理工具

| 工具 | 功能 |
|------|------|
| Clotilde | 每会话独立设置 + 预设 + 上下文 + 隐身会话 + HTML 导出 |
| CC Switch | 多服务商切换 |

## 待实施计划 (PLAN.md)

### Phase 1: Buddy 系统 ✅ 已完成
### Phase 2: 用量/配额监控（高优先级）
- 读取 rollout JSONL 的 `rate_limits` → 5h/7d 窗口追踪
- 收起状态微型进度条 + 展开状态完整面板 + 告警

### Phase 3: 终端精准跳转（高优先级）
- cmux: `ps -Ax` → PID env vars → `cmux send`
- 新增 WezTerm/Kaku 支持

### Phase 4: 项目分组视图（中优先级）
- flat / project-grouped 切换

### Phase 5: 斜杠命令截获（中优先级）
- /cost /usage 等命令输出捕获

### Phase 6: 视觉优化（低优先级）
- 6 色状态点 + hover 效果 + glow dots 分隔线

### Phase 7: 音效细粒度（低优先级）
- 每事件独立开关

## 已知问题

1. **灵动岛点击响应** — 添加 `.onTapGesture` 后可能与 hover 交互冲突，需要测试验证
2. **buddy 在 API Key 模式不可用** — Claude Code 的 `/buddy` 命令在 API Key 模式下显示 "unavailable"，但 CodeIsland 自己的 buddy 卡片不受影响
3. **开屏壁纸** — `onboarding-wallpaper.jpg` 资源可能不在 Bundle 中，fallback 到渐变背景
4. **SettingsView hasNotch 警告** — 158 行有一个未使用变量警告

## 依赖清单

- swift-markdown (v0.4.0+) — Markdown 渲染
- lottie-spm (v4.4.0+) — Lottie 动画
- ConfettiSwiftUI — 彩纸效果（开屏动画）
- any-buddy (npm, 可选) — buddy 外观自定义

## 参考项目

| 项目 | 位置 | 参考价值 |
|------|------|---------|
| Claude Island (farouqaldori) | `/tmp/claude-island/` | 聊天渲染、JSONL解析、像素角色 Canvas 动画 |
| CodeIsland (xmqywx) | `/tmp/xmqywx-codeisland/` | WyHash、BuddyReader、BuddyASCIIView、cmux 集成 |
| VibeIsland | `/Volumes/Vibe Island 3/Vibe Island.app/` | 弹窗设计、启动动画 |
| Open Vibe Island | github.com/Octane0411/open-vibe-island | Hook 管理、4 target 架构 |
| CinematicOnboardingView | github.com/adamlyttleapps | 电影级引导流 SwiftUI 实现 |
| AppleIntelligenceGlowEffect | github.com/jacobamobin | 纯 SwiftUI 流体光效 |
