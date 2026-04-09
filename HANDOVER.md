# CodeIsland → Claude Island 改造交接文档

## 项目位置
- **源码**: `/tmp/codeisland-ref/`
- **原项目**: https://github.com/wxtsky/CodeIsland
- **构建**: `cd /tmp/codeisland-ref && swift build`
- **运行**: `/tmp/codeisland-ref/.build/arm64-apple-macosx/debug/CodeIsland`

## 构建命令

```bash
cd /tmp/codeisland-ref
swift build
# 运行
pkill -f "CodeIsland" 2>/dev/null; sleep 1
.build/arm64-apple-macosx/debug/CodeIsland &
```

## 已完成的改造

### 1. Lottie 动画系统
- **文件**: `Package.swift` (添加 lottie-spm 依赖)
- **资源**: `Sources/CodeIsland/Resources/` (6 个 .lottie 文件)
  - `loading.lottie` — 加载动画
  - `typing.lottie` — 打字动画
  - `mascot-idle.lottie` — 角色待机
  - `mascot-working.lottie` — 角色工作
  - `mascot-question.lottie` — 角色疑问
  - `mascot-idea.lottie` — 角色灵感
- **文件**: `Sources/CodeIsland/MascotView.swift` (重构)
  - 所有 Agent 统一使用 Lottie 动画（替代原来的像素角色）
  - `LottieMascotView`: 根据 AgentStatus 自动切换动画
  - 使用 `.id(lottieName)` 确保状态切换时重建动画
  - 资源通过 `Bundle.module` 加载（SPM 正确路径）

### 2. 红绿 Diff 预览
- **文件**: `Sources/CodeIsland/NotchPanelView.swift` (ApprovalBar)
- 替换原来的 2 行截断 diff 为逐行红绿 diff
- 新增 `DiffBlock` 组件:
  - 每行独立显示，带 +/- 前缀
  - 红色背景(删除) / 绿色背景(新增)
  - 最多显示 8 行，超出显示 "... +N more lines"

### 3. 紧凑条 Lottie 指示器
- **文件**: `Sources/CodeIsland/NotchPanelView.swift` (CompactRightWing)
- `LottieLoadingSpinner` — processing/running 时显示 loading 动画
- `LottieTypingIndicator` — waitingApproval/waitingQuestion 时显示 typing 动画
- 替代原来的铃铛脉冲 (`bell.fill` + `.symbolEffect(.pulse)`)

### 4. Claude 主题风格
- **文件**: `Sources/CodeIsland/NotchPanelView.swift`
  - 项目名活跃色: 绿色 → Claude 橙色 (#D97857)
  - 卡片悬停: 白色 → Claude 橙色高亮 + 橙色边框
  - 审批栏工具名: 金色 → Claude 橙色
  - 紧凑条计数: 绿色 → Claude 橙色
  - 角色图标增大: 32px → 40px, 容器 36px → 44px

### 5. Claude 风格紧凑条
- **文件**: `Sources/CodeIsland/NotchPanelView.swift` (CompactLeftWing)
  - 展开时左上角: CodeIsland AppLogoView → Claude 官方 sunburst SVG
  - ALL/STA/CLI 像素文字 → 衬线体 "All / Status / CLI" 按钮
  - 选中状态: 绿色 → Claude 橙色高亮 + 橙色背景
- **CompactRightWing**:
  - 图标按钮颜色: 白色 → Claude 橙色

### 6. 聊天界面 (Chat Panel)
- **文件**: `Sources/CodeIsland/IslandSurface.swift` (新增 `.chat(sessionId:)`)
- **文件**: `Sources/CodeIsland/NotchPanelView.swift` (新增 `ChatPanelView`)
  - 点击 Claude 来源的 SessionCard → 进入聊天视图
  - 聊天头部: 返回按钮 + 项目名 + 状态标签
  - 消息区: 用户消息(绿色 >) + AI 回复(橙色 $)
  - 处理中: Lottie loading + 当前工具名
  - 保护: chat surface 不被 hover 自动替换

### 7. 设置界面改造
- **文件**: `Sources/CodeIsland/SettingsView.swift`
  - 侧栏图标颜色 → Claude 暖色系（橙/金/紫/粉/绿/棕/蓝）
  - 侧栏标签 → 衬线体（serif design）
  - 分组标题: "CodeIsland" → "Claude Island"，衬线体 + Claude 橙色
  - 全局 tint → Claude 橙色（影响开关、Picker 等控件）
  - 内容区背景 → 暖色深色 (0.08, 0.06, 0.05)
  - About 页: Claude sunburst logo + 渐变橙色 "Claude Island" 艺术字
- **文件**: `Sources/CodeIsland/SettingsWindowController.swift`
  - 窗口标题 → "Claude Island Settings"
  - 窗口背景 → 暖色深色

## 文件修改清单

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `Package.swift` | 修改 | 添加 lottie-spm 依赖 |
| `Sources/CodeIsland/MascotView.swift` | 重构 | Lottie 角色替代像素角色 |
| `Sources/CodeIsland/NotchPanelView.swift` | 大改 | Diff预览 + Lottie指示器 + Claude主题 + 聊天界面 + 紧凑条 |
| `Sources/CodeIsland/IslandSurface.swift` | 修改 | 新增 .chat surface |
| `Sources/CodeIsland/SettingsView.swift` | 修改 | Claude主题色/字体/About页 |
| `Sources/CodeIsland/SettingsWindowController.swift` | 修改 | 窗口标题和背景 |
| `Sources/CodeIsland/Resources/*.lottie` | 新增 | 6个Lottie动画文件 |

## 关键架构

### 事件流
```
Claude Code → Hook (Python/Bridge) → Unix Socket → HookServer → AppState → UI
                                                        ↓
                                                    SessionSnapshot
                                                        ↓
                                          NotchPanelView (compact bar + expanded content)
                                                        ↓
                          SessionCard / ApprovalBar / ChatPanelView / QuestionBar
```

### 面板内容切换 (IslandSurface)
- `.collapsed` → 仅紧凑条
- `.sessionList` → 会话列表
- `.approvalCard(sessionId)` → 权限审批卡片
- `.questionCard(sessionId)` → 问答卡片
- `.completionCard(sessionId)` → 完成通知
- `.chat(sessionId)` → 聊天视图 (新增)

## 待完成事项

### 优先级高
1. **完整聊天历史** — 解析 JSONL 文件获取完整对话历史（目前只显示 recentMessages 的最近 3 条）
2. **聊天输入框** — 通过 tmux 发送消息给 Claude Code
3. **Cursor 聊天支持** — 扩展聊天功能到 Cursor 来源的会话

### 优先级中
4. **角色预览页** — 设置中展示 Lottie 动画预览
5. **启动音效** — app 启动时播放 8-bit boot 音
6. **全局快捷键** — ⌘Y/⌘N 审批快捷键

### 优先级低
7. **自定义主题** — 用户可切换 Claude / 原始 / 自定义主题
8. **Sparkle 自动更新** — 配置 feed URL
