# Copilot CLI 工具映射

Skills 使用的是 Claude Code 的工具名。遇到这些工具时，请使用你所在平台的对应工具：

| Skill 引用 | Copilot CLI 对应项 |
|-----------------|----------------------|
| `Read`（读取文件） | `view` |
| `Write`（创建文件） | `create` |
| `Edit`（编辑文件） | `edit` |
| `Bash`（运行命令） | `bash` |
| `Grep`（搜索文件内容） | `grep` |
| `Glob`（按名称搜索文件） | `glob` |
| `Skill` 工具（调用 skill） | `skill` |
| `WebFetch` | `web_fetch` |
| `Task` 工具（分派子代理） | `task`（见下面的代理类型部分） |
| 多个 `Task` 调用（并行） | 多个 `task` 调用 |
| Task 状态/输出 | `read_agent`、`list_agents` |
| `TodoWrite`（任务跟踪） | `sql`，使用内置的 `todos` 表 |
| `WebSearch` | 无对应项 - 使用搜索引擎 URL 配合 `web_fetch` |
| `EnterPlanMode` / `ExitPlanMode` | 无对应项 - 保持在主会话中 |

## 代理类型

Copilot CLI 的 `task` 工具接受一个 `agent_type` 参数：

| Claude Code 代理 | Copilot CLI 对应项 |
|-------------------|----------------------|
| `general-purpose` | `"general-purpose"` |
| `Explore` | `"explore"` |
| 命名插件代理（例如 `superpowers:code-reviewer`） | 从已安装插件中自动发现 |

## 异步 shell 会话

Copilot CLI 支持持久化的异步 shell 会话，Claude Code 没有直接对应项：

| 工具 | 用途 |
|------|---------|
| `bash`，并设置 `async: true` | 在后台启动长时间运行的命令 |
| `write_bash` | 向正在运行的异步会话发送输入 |
| `read_bash` | 读取异步会话的输出 |
| `stop_bash` | 终止异步会话 |
| `list_bash` | 列出所有活动的 shell 会话 |

## Copilot CLI 的额外工具

| 工具 | 用途 |
|------|---------|
| `store_memory` | 为未来会话持久化代码库事实 |
| `report_intent` | 在 UI 状态栏中更新当前意图 |
| `sql` | 查询会话的 SQLite 数据库（todos、元数据） |
| `fetch_copilot_cli_documentation` | 查找 Copilot CLI 文档 |
| GitHub MCP 工具（`github-mcp-server-*`） | 原生 GitHub API 访问（issues、PR、代码搜索） |
