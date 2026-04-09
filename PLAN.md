# CodeIsland 功能升级计划

> 基于 xmqywx/CodeIsland 和 Open Vibe Island 的功能差距分析

---

## Phase 1: Claude Code Buddy 集成（高优先级）

### 1.1 Buddy Species 系统

实现 Claude Code `/buddy` 的完整 18 种 species 渲染。

**18 种 species 列表：**

| ID | Species | 描述 |
|----|---------|------|
| 1 | duck | 鸭子 |
| 2 | goose | 鹅 |
| 3 | blob | 水滴/果冻 |
| 4 | cat | 猫 |
| 5 | dragon | 龙 |
| 6 | octopus | 章鱼 |
| 7 | owl | 猫头鹰 |
| 8 | penguin | 企鹅 |
| 9 | turtle | 海龟 |
| 10 | snail | 蜗牛 |
| 11 | ghost | 幽灵 |
| 12 | axolotl | 六角恐龙 |
| 13 | capybara | 水豚 |
| 14 | cactus | 仙人掌 |
| 15 | robot | 机器人 |
| 16 | rabbit | 兔子 |
| 17 | mushroom | 蘑菇 |
| 18 | chonk | 胖墩 |

**实现步骤：**

1. 读取 `~/.claude.json` 获取用户的 buddy 名称和人格数据
2. 实现 `Bun.hash + Mulberry32` 算法（与 Claude Code 一致），计算 species/rarity/stats
3. 支持动态 salt 检测 — 从 Claude Code 二进制读取实际 salt
4. 为每种 species 创建 ASCII art sprite（idle 动画序列：blink, fidget）

**新增文件：**
- `Sources/CodeIsland/BuddyService.swift` — buddy 数据读取 + hash 算法
- `Sources/CodeIsland/BuddyAsciiArt.swift` — 18 种 species 的 ASCII art 定义
- `Sources/CodeIsland/BuddyCardView.swift` — buddy 卡片视图

### 1.2 Stats 系统（5 项属性）

| 属性 | 说明 |
|------|------|
| DEBUGGING | 调试能力 |
| PATIENCE | 耐心值 |
| CHAOS | 混乱度 |
| WISDOM | 智慧值 |
| SNARK | 毒舌值 |

每项属性用 ASCII 进度条展示：`[████████░░]`

### 1.3 Rarity 星级系统

| 等级 | 星数 | 颜色 |
|------|------|------|
| Common | ★ | 灰色 |
| Uncommon | ★★ | 绿色 |
| Rare | ★★★ | 蓝色 |
| Epic | ★★★★ | 紫色 |
| Legendary | ★★★★★ | 金色 |

### 1.4 Buddy 卡片 UI

左右布局：
- **左侧**：ASCII art sprite + buddy 名称
- **右侧**：ASCII stat bars + personality 标签 + rarity 星级

触发方式：点击灵动岛左翼的吉祥物图标展开 buddy 卡片。

---

## Phase 2: 用量/配额监控（高优先级）

### 2.1 数据源

- 读取 `~/.claude/` 下的 rollout JSONL 文件中的 `rate_limits` 字段
- 解析 5 小时窗口和 7 天窗口的使用数据
- 缓存到本地（如 `/tmp/codeisland-rl.json`）

### 2.2 UI 展示

**收起状态 — 右翼新增用量指示器：**
- 微型进度条（宽 30px，高 3px）
- 颜色编码：绿色 < 70%，黄色 70-90%，红色 > 90%

**展开状态 — Session 列表底部新增用量面板：**
- 5h 窗口进度条 + 百分比
- 7d 窗口进度条 + 百分比
- 预计恢复时间文本
- 按模型分别显示（Claude Sonnet / Opus）

### 2.3 告警

- 当用量 > 80% 时，灵动岛边框显示黄色脉冲
- 当用量 > 95% 时，自动弹出通知卡片

**新增文件：**
- `Sources/CodeIsland/UsageTracker.swift` — 用量数据采集 + 缓存
- `Sources/CodeIsland/UsageBarView.swift` — 用量进度条组件

---

## Phase 3: 终端精准跳转（高优先级）

### 3.1 cmux 深度集成

当前问题：PTY 直写在 cmux 中不工作。

**参考 xmqywx 的实现方案：**

1. `ps -Ax` 查找 `claude --session-id <id>` 进程
2. `ps -E -p <pid>` 读取环境变量 `CMUX_WORKSPACE_ID` 和 `CMUX_SURFACE_ID`
3. `cmux send --workspace <wid> --surface <sid> -- <message>` 精确路由

**回退策略：**
- 如果 Claude PID 被 `--resume` 轮换，按 `cwd` 匹配最高 PID 的 cmux-hosted Claude
- 非 cmux 终端 fallback 到 AppleScript（已有实现）

### 3.2 新增终端支持

| 终端 | 跳转方式 | 当前状态 |
|------|---------|---------|
| cmux | cmux send + Unix socket API | 待实现 |
| WezTerm | CLI pane targeting | 待实现 |
| Kaku | CLI pane targeting | 待实现 |

**修改文件：**
- `Sources/CodeIsland/TerminalSender.swift` — 新增 cmux/WezTerm/Kaku 策略
- `Sources/CodeIsland/TerminalActivator.swift` — 新增终端检测

---

## Phase 4: 项目分组视图（中优先级）

### 4.1 分组模式

在 Session List 中新增分组切换：
- **Flat 模式**（当前）：所有会话平铺列表
- **Project 模式**：按 working directory 分组，可折叠的 project header

### 4.2 UI 设计

```
┌─ ~/projects/api (2 sessions) ▾ ─────┐
│  Claude · fix auth bug · ⚡ Working  │
│  Codex  · backend server · 📖 Read  │
├─ ~/projects/web (1 session) ▾ ──────┤
│  Gemini · optimize queries · ✅ Done │
└─────────────────────────────────────┘
```

Header 显示：
- 项目路径（最后两级）
- 活跃会话数
- 折叠/展开 chevron

**修改文件：**
- `Sources/CodeIsland/NotchPanelView.swift` — SessionListView 重构
- `Sources/CodeIsland/Settings.swift` — 新增 `sessionGroupingMode` 设置项

---

## Phase 5: 斜杠命令截获（中优先级）

### 5.1 支持的命令

| 命令 | 功能 |
|------|------|
| `/cost` | 查看当前会话成本 |
| `/usage` | 查看使用统计 |
| `/model` | 查看当前模型 |
| `/clear` | 清除上下文 |
| `/compact` | 压缩上下文 |

### 5.2 实现方式

1. 通过 cmux 或 ACP 注入斜杠命令
2. 快照 cmux pane (`cmux capture-pane`)
3. 注入命令后每 200ms 轮询 pane 内容
4. diff 前后快照，提取新输出
5. 在灵动岛的聊天视图中显示输出

**新增文件：**
- `Sources/CodeIsland/SlashCommandService.swift` — 命令注入 + 输出捕获

---

## Phase 6: 视觉优化（低优先级）

### 6.1 状态点颜色系统（6 色）

| 状态 | 颜色 | 含义 |
|------|------|------|
| working | 🟦 Cyan | 正在工作 |
| waitingApproval | 🟧 Amber | 等待审批 |
| done | 🟩 Green | 完成/等待输入 |
| thinking | 🟣 Purple | 思考中 |
| error | 🔴 Red | 错误/超过 60s 无人看 |
| unattended | 🟠 Orange | 超过 30s 无人看 |

### 6.2 Session 行 Hover 效果

- 鼠标悬停时行背景高亮（白色 5% opacity）
- 终端图标从灰色变为金色
- 微弹动画 (scaleEffect 1.0 → 1.02)

### 6.3 Glow Dots 渐变分隔线

用渐变发光点替代普通分隔线：
- 中心亮，两端暗
- 颜色跟随当前会话的 agent 主色调

**修改文件：**
- `Sources/CodeIsland/NotchPanelView.swift` — 状态颜色映射 + hover 效果
- `Sources/CodeIsland/Models.swift` — AgentStatus 扩展颜色属性

---

## Phase 7: 音效细粒度控制（低优先级）

### 7.1 每事件独立开关

| 事件 | 默认 |
|------|------|
| Session start | ON |
| Processing begins | OFF |
| Needs approval | ON |
| Approval granted | ON |
| Approval denied | ON |
| Session complete | ON |
| Error | ON |
| Context compacting | OFF |

### 7.2 8-bit 芯片音乐风格

为每种事件创建独立的 8-bit 芯片音效文件。

**修改文件：**
- `Sources/CodeIsland/SoundManager.swift` — 每事件开关
- `Sources/CodeIsland/SettingsView.swift` — 音效设置 UI

---

## 实施顺序

```
Phase 1 (Buddy) ─┐
Phase 2 (用量)   ├─→ v2.0 Release
Phase 3 (终端)   ─┘

Phase 4 (分组)   ─┐
Phase 5 (命令)   ├─→ v2.1 Release
Phase 6 (视觉)   ─┘

Phase 7 (音效)   ──→ v2.2 Release
```

## 依赖

- Bun (可选，buddy stats 计算 fallback 到 Swift 实现)
- cmux CLI (终端跳转)
- 现有依赖不变（swift-markdown, lottie-spm）
