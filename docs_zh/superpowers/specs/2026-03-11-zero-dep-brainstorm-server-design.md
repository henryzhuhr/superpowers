# 零依赖 Brainstorm Server

将 brainstorm companion server 中 vendored 的 `node_modules`（express、ws、chokidar，共 714 个已跟踪文件）替换为单个零依赖的 `server.js`，只使用 Node.js 内建模块。

## 动机

把 `node_modules` vendoring 到 git 仓库里会带来供应链风险：冻结的依赖拿不到安全补丁，714 个第三方文件未经审计就被提交，而且对 vendored 代码的修改看起来和普通提交没有区别。虽然实际风险较低（仅限 localhost 的开发服务器），但消除它并不复杂。

## 架构

使用单个 `server.js` 文件（约 250 到 300 行），依赖 `http`、`crypto`、`fs` 和 `path`。该文件承担两个角色：

- **直接运行时**（`node server.js`）：启动 HTTP/WebSocket 服务器
- **被 require 时**（`require('./server.js')`）：导出 WebSocket 协议函数供单元测试使用

### WebSocket 协议

仅实现 RFC 6455 中的文本帧：

**握手：** 使用客户端的 `Sec-WebSocket-Key` 加上 RFC 6455 的 magic GUID，通过 SHA-1 计算 `Sec-WebSocket-Accept`。返回 101 Switching Protocols。

**帧解码（客户端到服务端）：** 处理三种带 mask 的长度编码：
- 小：payload 小于 126 字节
- 中：126 到 65535 字节（16 位扩展长度）
- 大：大于 65535 字节（64 位扩展长度）

使用 4 字节 mask key 对 payload 做 XOR 解码。返回 `{ opcode, payload, bytesConsumed }`，如果 buffer 不完整则返回 `null`。拒绝未带 mask 的帧。

**帧编码（服务端到客户端）：** 不带 mask 的帧，使用相同的三种长度编码。

**处理的 opcode：** TEXT（0x01）、CLOSE（0x08）、PING（0x09）、PONG（0x0A）。无法识别的 opcode 会返回状态码 1003（Unsupported Data）的 close frame。

**刻意跳过：** 二进制帧、分片消息、扩展（permessage-deflate）、子协议。这些对于 localhost 客户端之间的小型 JSON 文本消息没有必要。扩展和子协议需要在握手阶段协商，只要不声明支持，它们就永远不会启用。

**Buffer 累积：** 每个连接维护一个 buffer。收到 `data` 后，追加进去并循环调用 `decodeFrame`，直到它返回 null 或 buffer 为空。

### HTTP 服务器

三个路由：

1. **`GET /`**：按 mtime 返回 screen 目录中最新的 `.html` 文件。识别完整文档和片段，对片段进行 frame template 包装并注入 `helper.js`。返回 `text/html`。如果没有 `.html` 文件，则返回一个硬编码的等待页面（"Waiting for Claude to push a screen..."），并注入 `helper.js`。
2. **`GET /files/*`**：从 screen 目录提供静态文件，MIME 类型通过硬编码的扩展名映射查找（html、css、js、png、jpg、gif、svg、json）。找不到则返回 404。
3. **其他所有路径**：404。

WebSocket upgrade 通过 HTTP server 的 `'upgrade'` 事件处理，与普通请求处理分离。

### 配置

环境变量（全部可选）：

- `BRAINSTORM_PORT`：绑定端口（默认：49152 到 65535 之间的随机高位端口）
- `BRAINSTORM_HOST`：绑定网卡（默认：`127.0.0.1`）
- `BRAINSTORM_URL_HOST`：启动 JSON 中 URL 使用的主机名（默认：当 host 为 `127.0.0.1` 时使用 `localhost`，否则与 host 相同）
- `BRAINSTORM_DIR`：screen 目录路径（默认：`/tmp/brainstorm`）

### 启动流程

1. 如果 `SCREEN_DIR` 不存在则创建（`mkdirSync` recursive）
2. 从 `__dirname` 加载 frame template 和 `helper.js`
3. 在配置的 host/port 上启动 HTTP server
4. 对 `SCREEN_DIR` 启动 `fs.watch`
5. 成功监听后，将 `server-started` JSON 记录到 stdout：`{ type, port, host, url_host, url, screen_dir }`
6. 把相同 JSON 写入 `SCREEN_DIR/.server-info`，这样当 stdout 被隐藏时（后台执行），agent 仍然能找到连接信息

### 应用层 WebSocket 消息

当收到客户端发来的 TEXT frame 时：

1. 解析为 JSON。解析失败时记录到 stderr，然后继续。
2. 以 `{ source: 'user-event', ...event }` 形式写入 stdout。
3. 如果事件中包含 `choice` 属性，则把该 JSON 追加到 `SCREEN_DIR/.events`（每个事件一行）。

### 文件监听

`fs.watch(SCREEN_DIR)` 取代 chokidar。对 HTML 文件事件：

- 新文件（`rename` 事件且文件存在）时：如果 `.events` 文件存在则删除（`unlinkSync`），并将 `screen-added` 作为 JSON 记录到 stdout
- 文件变更（`change` 事件）时：将 `screen-updated` 作为 JSON 记录到 stdout（**不要**清空 `.events`）
- 两种事件都要向所有已连接 WebSocket 客户端发送 `{ type: 'reload' }`

按文件名做约 100ms 的 debounce，防止重复事件（在 macOS 和 Linux 上很常见）。

### 错误处理

- WebSocket 客户端发来格式错误的 JSON：记录到 stderr，继续
- 未处理的 opcode：以状态 1003 关闭
- 客户端断开：从广播集合中移除
- `fs.watch` 错误：记录到 stderr，继续
- 不做优雅关闭逻辑，shell 脚本通过 SIGTERM 管理进程生命周期

## 变化内容

| 之前 | 之后 |
|---|---|
| `index.js` + `package.json` + `package-lock.json` + 714 个 `node_modules` 文件 | `server.js`（单文件） |
| 依赖 express、ws、chokidar | 无依赖 |
| 不支持静态文件服务 | `/files/*` 从 screen 目录提供静态文件 |

## 保持不变的内容

- `helper.js`：无改动
- `frame-template.html`：无改动
- `start-server.sh`：只需一行更新，从 `index.js` 改为 `server.js`
- `stop-server.sh`：无改动
- `visual-companion.md`：无改动
- 所有现有服务端行为和对外契约

## 平台兼容性

- `server.js` 仅使用跨平台的 Node 内建模块
- `fs.watch` 对 macOS、Linux 和 Windows 上的单层平面目录都足够可靠
- Shell 脚本需要 bash（Windows 上需要 Git Bash，而 Claude Code 本身就依赖它）

## 测试

**单元测试**（`ws-protocol.test.js`）：通过 require `server.js` 导出的函数，直接测试 WebSocket 帧编码/解码、握手计算以及协议边界情况。

**集成测试**（`server.test.js`）：测试完整服务端行为，包括 HTTP 服务、WebSocket 通信、文件监听和 brainstorming 工作流。使用 `ws` npm 包作为测试专用的客户端依赖（不会随产品分发给终端用户）。
