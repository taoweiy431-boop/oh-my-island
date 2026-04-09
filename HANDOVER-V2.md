# CodeIsland 改造交接文档 V2

## 项目位置
- **源码**: `/tmp/codeisland-ref/`
- **构建**: `cd /tmp/codeisland-ref && swift build`
- **运行**: `pkill -f "CodeIsland" 2>/dev/null; sleep 1; .build/arm64-apple-macosx/debug/CodeIsland &`
- **Claude Island 参考**: `/tmp/claude-island/` (farouqaldori fork)
- **VibeIsland 参考**: `/Volumes/Vibe Island 3/Vibe Island.app/`

## 本次新增/修改的文件

### 新文件

| 文件 | 行数 | 说明 |
|------|------|------|
| `Sources/CodeIsland/ChatModels.swift` | ~320 | ChatHistoryItem, ToolCallItem, ToolResultData, ToolStatusDisplay, MCPToolFormatter |
| `Sources/CodeIsland/ChatComponents.swift` | ~260 | MarkdownText (swift-markdown), ProcessingSpinner, RoundedCorner |
| `Sources/CodeIsland/ToolResultViews.swift` | ~550 | 16种工具结果渲染视图, SimpleDiffView (LCS), FileCodeView, CodePreview |
| `Sources/CodeIsland/ChatView.swift` | ~500 | 新聊天视图 (替换 ChatPanelView), JSONL 解析, ACP/Terminal 双模式发送 |
| `Sources/CodeIsland/ACPClient.swift` | ~300 | ACP 客户端 (JSON-RPC over stdio), claude-code-acp adapter 管理 |
| `Sources/CodeIsland/TerminalSender.swift` | ~200 | 多策略终端消息注入 (PTY/tmux/AppleScript/进程扫描) |
| `Sources/CodeIsland/PopupWindows.swift` | ~280 | VibeIsland 风格独立弹窗 (权限审批 + 问答) |

### 修改文件

| 文件 | 改动 |
|------|------|
| `Package.swift` | 添加 swift-markdown 依赖 |
| `NotchPanelView.swift` | ChatPanelView 引用替换为 ChatView, 旧 ChatPanelView 删除 |
| `AppState.swift` | showNextPending() 中集成 PopupWindows 弹窗 |

## 功能状态

### ✅ 已完成

1. **聊天渲染系统** — 从 Claude Island fork 移植
   - 用户消息右对齐圆角气泡
   - AI 回复左对齐 + 白色圆点 + Markdown 渲染 (swift-markdown)
   - 工具调用可折叠卡片 (状态圆点脉冲 + 结果预览)
   - 思考内容灰色斜体可展开
   - `✳ Processing...` 符号旋转动画

2. **16 种工具结果渲染** — Read/Edit/Write/Bash/Grep/Glob/TodoWrite/Task/WebFetch/WebSearch 等
   - SimpleDiffView: LCS 算法行级 diff (带行号、文件名头部)
   - FileCodeView: 带行号的代码文件预览
   - 每种工具有专属状态文案 (ToolStatusDisplay)

3. **ACP 客户端** — Agent Client Protocol 集成
   - 自动查找 claude-code-acp adapter (npx/nvm/volta/bun)
   - JSON-RPC over stdio (换行分隔 JSON)
   - initialize → session/new → session/prompt 完整流程
   - 自动加载 ~/.claude/settings.json 的环境变量 (ccswitch 代理支持)
   - 30 秒超时机制
   - **已验证**: 连接成功, 收到 Claude 回复

4. **权限审批/问答弹窗** — VibeIsland 风格
   - PermissionPopupView: 橙色主题, diff 预览, Deny(⌘N)/Allow(⌘Y)
   - QuestionPopupView: 青色主题, 选项列表(⌘1/2/3), 文本输入框
   - NSPanel 悬浮窗口, spring 动画入场
   - 集成到 AppState.showNextPending()

### ⚠️ 需要继续完善

1. **终端消息注入** — PTY 写入在 Superset/cmux 中不工作
   - 可能方案: stream-json 模式, Channels 插件, Agent Bridge
   - 参见下方"消息发送方案对比"

2. **弹窗测试** — 需要用真正的 Claude Code 权限请求测试
   - 确保 Claude Code 不开 `--dangerously-skip-permissions`
   - 测试 peer disconnect 时弹窗是否正常消失

3. **聊天历史同步** — JSONL 解析器目前比较基础
   - 缺少增量解析 (每次全量读取)
   - 缺少 tool_result 的结构化解析
   - 参考 Claude Island 的 ConversationParser.swift (1057行)

## 消息发送方案对比

| 方案 | 终端同步 | 零配置 | 适用范围 | 状态 |
|------|---------|--------|---------|------|
| PTY 直写 | ✅ | ✅ | Terminal.app ✅, iTerm ✅, Superset ❌ | 部分可用 |
| tmux send-keys | ✅ | ❌ 需要 tmux | tmux 环境 | 已实现 |
| AppleScript | ✅ | ✅ | Terminal.app ✅, iTerm ✅ | 已实现 |
| ACP (独立模式) | ❌ | ❌ 需要 adapter | 任何环境 | 已实现已验证 |
| stream-json SDK | ❌ | ✅ | 任何环境 | 未实现 |
| Channels 插件 | ✅ | ❌ 需要 --channels | 任何环境 | 未实现 |
| Agent Bridge | ✅ | ❌ 需要包裹启动 | 任何环境 | 参考 ThinkerYzu/agent-bridge |

## 启动动画实现提示词

### 结构设计

参考 VibeIsland 的 Onboarding 仪式 — 三层窗口叠加：

```
┌─────────────────────────────────────┐ ← OnboardingFullscreenWindow (全屏)
│  ┌─────────────────────────────────┐│    模糊壁纸 + 暗色遮罩
│  │     模糊壁纸背景               ││
│  │                                 ││
│  │    ┌───────────────────┐       ││ ← OnboardingCardWindow (居中卡片)
│  │    │ ╭─────────────╮   │       ││    灵动岛形状, 旋转光晕
│  │    │ │  CodeIsland  │   │       ││
│  │    │ ╰─────────────╯   │       ││
│  │    └───────────────────┘       ││
│  │                                 ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

### 提示词 (给 AI 实现)

```
为 CodeIsland (macOS Swift notch bar app) 实现一个电影级启动动画:

1. 全屏窗口 (OnboardingFullscreenWindow):
   - 黑色背景渐入 (opacity 0→1, 0.5s)
   - 壁纸图片 (onboarding-wallpaper.jpg) 高斯模糊(radius 30) + 暗化(overlay 60% 黑)
   - 缓慢缩放 (scale 1.05→1.0, 8s ease-out) 制造景深感

2. 灵动岛卡片 (OnboardingCardWindow):
   - 从 notch 位置(屏幕顶部中央)缓慢下移展开
   - 形状: 圆角矩形 (cornerRadius 24), 初始小(灵动岛大小)→ 放大到卡片大小
   - 光晕效果: AngularGradient 围绕卡片旋转 (3s/圈, 颜色: 橙→金→白→蓝→紫→橙)
   - 光晕强度: 0→1 渐入(1s), 然后持续旋转
   - 卡片内容: Logo + "CodeIsland" 文字 + 版本号

3. 分步展示 (3-4步):
   - 步骤用 spring 动画切换
   - 每步展示一个功能介绍
   - 最后一步: "Ready" + 启动按钮

4. 退出动画:
   - 卡片收缩回 notch 位置 (scale + position, 0.6s spring)
   - 全屏窗口渐出 (0.3s)
   - 光晕消散 (opacity 0, 0.5s)

技术要求:
- 使用 NSWindow (非 SwiftUI 窗口) 实现全屏
- NSPanel 实现浮动卡片
- SwiftUI View 作为内容
- 光晕使用 Canvas + AngularGradient + rotationEffect
- 窗口层级: fullscreen(.screenSaver) + card(.floating)
```

### 音效衬托提示词

```
为 CodeIsland 的启动动画创建音效:

场景: macOS notch bar 灵动岛应用的电影级启动仪式

音效序列:
1. 0.0s - 低沉的共鸣音 (类似 Mac 开机音, 但更柔和, 带混响)
2. 0.5s - 渐入的环境音垫 (ambient pad, 空灵感, 类似太空漂浮)  
3. 1.5s - 光晕出现时的微妙闪光音 (subtle shimmer, 类似水晶)
4. 3.0s - 每个步骤切换时的轻柔点击音 (soft click + whoosh)
5. 最终步骤 - 成功完成音 (上升的和弦, 明亮且满足, 类似成就解锁)

风格参考:
- Apple 产品视频的音效风格
- 简洁、现代、有质感
- 频率范围: 低音共鸣(100-200Hz) + 高频闪光(2-6kHz)
- 持续时间: 整个序列 5-8 秒

格式要求:
- 44.1kHz / 16bit WAV 或 CAF
- 每个音效独立文件 (方便 SwiftUI 触发)
- 或合并为一个时间轴音频
```

## 依赖清单

- swift-markdown (v0.4.0+) — Markdown 渲染
- lottie-spm (v4.4.0+) — Lottie 动画 (已有)
- @zed-industries/claude-code-acp (npm, v0.16.2) — ACP adapter (可选)

## 关键参考项目

| 项目 | 位置 | 参考价值 |
|------|------|---------|
| Claude Island (farouqaldori) | `/tmp/claude-island/` | 聊天渲染、JSONL解析、消息发送 |
| VibeIsland | `/Volumes/Vibe Island 3/Vibe Island.app/` | 弹窗设计、启动动画、OpenCode集成 |
| Agent Bridge | `/tmp/agent-bridge/` | PTY拦截 + HTTP API 注入 |
| ACP 协议文档 | https://agentclientprotocol.com/ | 标准化 Agent 通信 |
| Claude Code Channels | https://code.claude.com/docs/en/channels.md | 双向消息推送 |
