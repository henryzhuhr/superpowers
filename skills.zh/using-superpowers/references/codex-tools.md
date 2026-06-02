# Codex 工具映射

Skills 使用的是 Claude Code 的工具名。遇到这些工具时，请使用你所在平台的对应工具：

| Skill 引用 | Codex 对应项 |
|-------------------|------------------|
| `Task` 工具（分派子代理） | `spawn_agent`（见下面的命名代理分派部分） |
| 多个 `Task` 调用（并行） | 多个 `spawn_agent` 调用 |
| Task 返回结果 | `wait` |
| Task 自动完成 | 用 `close_agent` 释放名额 |
| `TodoWrite`（任务跟踪） | `update_plan` |
| `Skill` 工具（调用 skill） | Skills 原生加载 - 直接遵循指令即可 |
| `Read`、`Write`、`Edit`（文件） | 使用你原生的文件工具 |
| `Bash`（运行命令） | 使用你原生的 shell 工具 |

## 子代理分派需要多代理支持

在 Codex 配置中添加（`~/.codex/config.toml`）：

```toml
[features]
multi_agent = true
```

这会为 `dispatching-parallel-agents` 和 `subagent-driven-development` 之类的 skills 启用 `spawn_agent`、`wait` 和 `close_agent`。

## 命名代理分派

Claude Code skills 会引用像 `superpowers:code-reviewer` 这样的命名代理类型。
Codex 没有命名代理注册表 - `spawn_agent` 会从内置角色（`default`、`explorer`、`worker`）创建通用代理。

当某个 skill 指示你分派一个命名代理类型时：

1. 找到该代理的提示词文件（例如 `agents/code-reviewer.md`，或该 skill 的局部提示模板，如 `code-quality-reviewer-prompt.md`）
2. 读取提示词内容
3. 填充任何模板占位符（`{BASE_SHA}`、`{WHAT_WAS_IMPLEMENTED}` 等）
4. 以填充后的内容作为 `message`，启动一个 `worker` 代理

| Skill 指令 | Codex 对应项 |
|-------------------|----------------------|
| `Task 工具（superpowers:code-reviewer）` | `spawn_agent(agent_type="worker", message=...)`，其中 `message` 使用 `code-reviewer.md` 的内容 |
| `Task 工具（通用）`，且提示词内联 | `spawn_agent(message=...)`，内容保持与原提示词一致 |

### `message` 的组织方式

`message` 参数是给模型的用户级输入，不是系统提示词。应将其组织成最大化指令遵循的形式：

```
Your task is to perform the following. Follow the instructions below exactly.

<agent-instructions>
[filled prompt content from the agent's .md file]
</agent-instructions>

Execute this now. Output ONLY the structured response following the format
specified in the instructions above.
```

- 使用任务分派式表述（“Your task is...”），而不是人格化表述（“You are...”）
- 用 XML 标签包裹指令 - 模型会把带标签的内容视为更权威
- 结尾加上明确的执行指令，避免只对指令做总结

### 何时可以移除这个替代方案

这个方案是为了弥补 Codex 的插件系统目前还没有 `agents` 字段。等 `RawPluginManifest` 增加了 `agents` 字段后，这个插件就可以符号链接到 `agents/`（与现有的 `skills/` 符号链接方式一致），skills 也可以直接分派命名代理类型。

## 环境检测

创建 worktree 或完成分支的 skills，应在继续之前使用只读 git 命令检测当前环境：

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` -> 已经在一个链接的 worktree 中（跳过创建）
- `BRANCH` 为空 -> 处于 detached HEAD（无法在沙箱中创建分支 / push / PR）

参见 `using-git-worktrees` 的 Step 0 和 `finishing-a-development-branch` 的 Step 1，了解各个 skill 如何使用这些信号。

## Codex App 收尾

当沙箱阻止分支 / push 操作时（例如外部管理的 worktree 处于 detached HEAD），代理应完成所有工作，并提示用户使用 App 的原生控件：

- **"Create branch"** - 先命名分支，然后通过 App UI 完成 commit / push / PR
- **"Hand off to local"** - 将工作转交到用户的本地 checkout

代理仍然可以运行测试、暂存文件，并输出建议的分支名、提交信息和 PR 描述供用户复制。
