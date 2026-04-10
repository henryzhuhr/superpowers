# 视觉化 Brainstorming 重构：浏览器负责展示，终端负责命令

**Date:** 2026-02-19
**Status:** Approved
**Scope:** `lib/brainstorm-server/`、`skills/brainstorming/visual-companion.md`、`tests/brainstorm-server/`

## 问题

在视觉化 brainstorming 期间，Claude 会把 `wait-for-feedback.sh` 作为后台任务运行，并阻塞在 `TaskOutput(block=true, timeout=600s)` 上。这会完全占住 TUI，用户在视觉化 brainstorming 运行时无法向 Claude 输入。浏览器因此变成唯一输入通道。

Claude Code 的执行模型是按 turn 进行的。在单个 turn 内，Claude 无法同时监听两个通道。阻塞式 `TaskOutput` 模式选错了原语，它在模拟平台并不支持的事件驱动行为。

## 设计

### 核心模型

**浏览器 = 交互式展示层。** 展示 mockup，让用户点击选择选项。选择结果记录在服务端。

**终端 = 对话通道。** 始终不阻塞，始终可用。用户在这里与 Claude 对话。

### 循环

1. Claude 把一个 HTML 文件写入会话目录
2. 服务端通过 chokidar 检测到它，并向浏览器推送 WebSocket reload（不变）
3. Claude 结束当前 turn，并告诉用户去浏览器查看后在终端回复
4. 用户查看浏览器，可选择点击某个选项，然后在终端输入反馈
5. 在下一轮 turn 中，Claude 读取 `$SCREEN_DIR/.events` 获取浏览器交互流（点击、选择），并与终端文本合并
6. 继续迭代或推进

不再有后台任务。不再有 `TaskOutput` 阻塞。不再有轮询脚本。

### 关键删除：`wait-for-feedback.sh`

彻底删除。它原本的作用是桥接“服务端把事件记录到 stdout”和“Claude 需要收到这些事件”。现在由 `.events` 文件取代这一职责，服务端直接把用户交互事件写进去，Claude 使用平台提供的任意文件读取机制即可读取。

### 关键新增：`.events` 文件（每个 screen 的事件流）

服务端会把所有用户交互事件写入 `$SCREEN_DIR/.events`，每行一个 JSON 对象。这样 Claude 就能拿到当前 screen 的完整交互流，不只是最终选择，还包括用户的探索路径（先点 A，再点 B，最终停在 C）。

用户探索选项后的示例内容：

```jsonl
{"type":"click","choice":"a","text":"Option A - Preset-First Wizard","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Manual Config","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid Approach","timestamp":1706000115}
```

- 在单个 screen 内追加写入。每个用户事件都会作为新的一行追加进去。
- 当 chokidar 检测到新的 HTML 文件（即新的 screen 被推送）时，会清空（删除）该文件，防止旧事件残留。
- 如果 Claude 读取时文件不存在，说明没有发生浏览器交互，此时 Claude 只使用终端文本。
- 文件中只包含用户事件（`click` 等），不包含服务端生命周期事件（`server-started`、`screen-added`）。这样文件会更小、更聚焦。
- Claude 可以读取完整事件流来理解用户的探索路径，也可以只看最后一个 `choice` 事件来获取最终选择。

## 按文件拆分的变更

### `index.js`（server）

**A. 把用户事件写入 `.events` 文件。**

在 WebSocket 的 `message` handler 中，事件写到 stdout 之后，使用 `fs.appendFileSync` 以 JSON Lines 形式追加到 `$SCREEN_DIR/.events`。只写入用户交互事件（即 `source: 'user-event'` 的事件），不要写入服务端生命周期事件。

**B. 在新 screen 时清空 `.events`。**

在 chokidar 的 `add` handler 中（检测到新的 `.html` 文件），如果 `$SCREEN_DIR/.events` 存在就删除它。这是“新 screen”最明确的信号，比在 GET `/` 时清空更好，因为后者会在每次 reload 时触发。

**C. 替换 `wrapInFrame` 的内容注入方式。**

当前正则锚定在 `<div class="feedback-footer">` 上，而这个节点将被移除。改成使用注释占位符：删除 `#claude-content` 内现有默认内容（`<h2>Visual Brainstorming</h2>` 和副标题段落），替换为单个 `<!-- CONTENT -->` 标记。内容注入改为 `frameTemplate.replace('<!-- CONTENT -->', content)`。这样更简单，也不会因为模板格式变化而失效。

### `frame-template.html`（UI frame）

**移除：**
- `feedback-footer` div（textarea、Send 按钮、label、`.feedback-row`）
- 关联的 CSS（`.feedback-footer`、`.feedback-footer label`、`.feedback-row`，以及其中 textarea 和 button 的样式）

**新增：**
- 在 `#claude-content` 中加入 `<!-- CONTENT -->` 占位符，替换默认文本
- 在原 footer 所在位置加入一个选择指示栏，包含两种状态：
  - 默认状态："Click an option above, then return to the terminal"
  - 选择后状态："Option B selected — return to terminal to continue"
- 选择指示栏的 CSS（低调，视觉权重与现有 header 类似）

**保持不变：**
- 带有 "Brainstorm Companion" 标题和连接状态的 header 栏
- `.main` 包装层和 `#claude-content` 容器
- 所有组件 CSS（`.options`、`.cards`、`.mockup`、`.split`、`.pros-cons`、占位符、mock 元素）
- 深色/浅色主题变量和 media query

### `helper.js`（客户端脚本）

**移除：**
- `sendToClaude()` 函数及其“Sent to Claude”整页接管逻辑
- `window.send()` 函数（原本绑定到被删除的 Send 按钮）
- 表单提交 handler，没有反馈 textarea 后就没有意义，而且会产生日志噪音
- 输入变化 handler，原因同上
- `pageshow` 事件监听器（原本是为修复 textarea 持久化问题添加的，现在已经没有 textarea）

**保留：**
- WebSocket 连接、重连逻辑、事件队列
- Reload handler（服务端推送时执行 `window.location.reload()`）
- `window.toggleSelect()` 用于高亮选择
- `window.selectedChoice` 状态跟踪
- `window.brainstorm.send()` 和 `window.brainstorm.choice()`，这两个和被删除的 `window.send()` 不同。它们调用 `sendEvent`，通过 WebSocket 向服务端写日志。对自定义完整页面仍然有用。

**收窄：**
- 点击 handler 只捕获 `[data-choice]` 点击，不再捕获所有按钮/链接。以前浏览器本身也是反馈通道，所以需要更宽的捕获范围；现在只需要做选择跟踪。

**新增：**
- 在点击 `data-choice` 时，更新选择指示栏文本，展示当前被选中的选项。

**从 `window.brainstorm` API 中移除：**
- `brainstorm.sendToClaude`，该接口不再存在

### `visual-companion.md`（技能说明）

**重写 “The Loop” 一节** 为上文所述的非阻塞流程。删除对以下内容的所有引用：
- `wait-for-feedback.sh`
- `TaskOutput` 阻塞
- 超时/重试逻辑（600 秒超时、30 分钟上限）
- 描述 `send-to-claude` JSON 的 “User Feedback Format” 一节

**替换为：**
- 新循环（写 HTML → 结束 turn → 用户在终端回复 → 读取 `.events` → 继续迭代）
- `.events` 文件格式说明
- 说明终端消息是主反馈通道，`.events` 作为附加上下文提供完整浏览器交互流

**保留：**
- 服务端启动/关闭说明
- 内容片段 vs 完整文档说明
- CSS 类参考和可用组件
- 设计建议（按问题调整保真度、每屏 2 到 4 个选项等）

### `wait-for-feedback.sh`

**完全删除。**

### `tests/brainstorm-server/server.test.js`

需要更新的测试：
- 断言片段响应中存在 `feedback-footer` 的测试，改为断言选择指示栏或 `<!-- CONTENT -->` 替换
- 断言 `helper.js` 包含 `send` 的测试，改为匹配收窄后的 API
- 断言 `sendToClaude` 使用 CSS 变量的测试，移除（该函数已不存在）

## 平台兼容性

服务端代码（`index.js`、`helper.js`、`frame-template.html`）完全与平台无关，都是纯 Node.js 和浏览器 JavaScript。它已经通过后台终端交互在 Codex 上验证可行。

技能说明（`visual-companion.md`）是平台适配层。各平台上的 Claude 使用各自的工具启动服务端、读取 `.events` 等。非阻塞模型天然适用于各个平台，因为它不依赖任何平台特有的阻塞原语。

## 这个方案带来的能力

- **TUI 在视觉化 brainstorming 期间始终可响应**
- **混合输入**：可以在浏览器点击，再在终端输入，两者自然合并
- **优雅降级**：浏览器挂掉了或用户没打开？终端仍然可用
- **架构更简单**：没有后台任务、没有轮询脚本、没有超时管理
- **跨平台**：相同的服务端代码可以运行在 Claude Code、Codex 和未来平台上

## 这个方案放弃的能力

- **纯浏览器反馈工作流**：用户必须回到终端才能继续。选择指示栏会提醒这一点，但相比以前“点击 Send 然后等待”的流程，确实多了一步。
- **浏览器内联文本反馈**：textarea 被移除了。所有文本反馈都走终端。这是有意为之，因为终端比 frame 中的小 textarea 更适合输入文字。
- **浏览器点击 Send 后立即响应**：旧系统会在用户点击 Send 的那一刻让 Claude 响应。现在用户需要切回终端，中间会有一个时间差。实际中通常只有几秒，而且用户还能顺便在终端补充上下文。
