# Gemini CLI 工具映射

Skills 使用的是 Claude Code 的工具名。遇到这些工具时，请使用你所在平台的对应工具：

| Skill 引用 | Gemini CLI 对应项 |
|-----------------|----------------------|
| `Read`（读取文件） | `read_file` |
| `Write`（创建文件） | `write_file` |
| `Edit`（编辑文件） | `replace` |
| `Bash`（运行命令） | `run_shell_command` |
| `Grep`（搜索文件内容） | `grep_search` |
| `Glob`（按名称搜索文件） | `glob` |
| `TodoWrite`（任务跟踪） | `write_todos` |
| `Skill` 工具（调用 skill） | `activate_skill` |
| `WebSearch` | `google_web_search` |
| `WebFetch` | `web_fetch` |
| `Task` 工具（分派子代理） | 无对应项 - Gemini CLI 不支持子代理 |

## 不支持子代理

Gemini CLI 没有与 Claude Code 的 `Task` 工具等价的能力。依赖子代理分派的 skills（`subagent-driven-development`、`dispatching-parallel-agents`）会回退为单会话执行，由 `executing-plans` 接管。

## Gemini CLI 的额外工具

Gemini CLI 中有一些工具可用，但 Claude Code 没有对应项：

| 工具 | 用途 |
|------|---------|
| `list_directory` | 列出文件和子目录 |
| `save_memory` | 将事实持久化到跨会话的 GEMINI.md |
| `ask_user` | 向用户请求结构化输入 |
| `tracker_create_task` | 更丰富的任务管理（创建、更新、列出、可视化） |
| `enter_plan_mode` / `exit_plan_mode` | 在进行修改之前切换到只读研究模式 |
