# Codex App 兼容性：Worktree 与收尾技能适配

让 superpowers 技能能够在 Codex App 的沙箱 worktree 环境中运行，同时不破坏现有 Claude Code 或 Codex CLI 的行为。

**Ticket:** PRI-823

## 动机

Codex App 会在它自己管理的 git worktree 中运行 agent，这些 worktree 处于 detached HEAD，位于 `$CODEX_HOME/worktrees/` 下，并且带有 Seatbelt 沙箱，会阻止 `git checkout -b`、`git push` 和网络访问。superpowers 中有三个技能默认假设 git 访问不受限制：`using-git-worktrees` 会创建带命名分支的手动 worktree，`finishing-a-development-branch` 会按分支名进行 merge/push/PR，而 `subagent-driven-development` 同时依赖这两者。

Codex CLI（开源终端工具）**不存在**这个冲突，它本身没有内建 worktree 管理。我们手动 worktree 的方案在那边正好补上了隔离能力缺口。问题只出现在 Codex App。

## 经验性发现

于 2026-03-23 在 Codex App 中测试：

| 操作 | workspace-write sandbox | Full access sandbox |
|---|---|---|
| `git add` | 可用 | 可用 |
| `git commit` | 可用 | 可用 |
| `git checkout -b` | **被阻止**（不能写 `.git/refs/heads/`） | 可用 |
| `git push` | **被阻止**（网络 + `.git/refs/remotes/`） | 可用 |
| `gh pr create` | **被阻止**（网络） | 可用 |
| `git status/diff/log` | 可用 | 可用 |

其他发现：
- `spawn_agent` subagent **共享**父线程文件系统（已通过 marker file 测试确认）
- 无论 worktree 起始于哪个分支，App 头部都会出现 “Create branch” 按钮
- App 的原生收尾流程是：Create branch → Commit modal → Commit and push / Commit and create PR
- `network_access = true` 配置在 macOS 上会静默失效（issue #10390）

## 设计：只读环境检测

使用三个只读 git 命令，无副作用地检测环境：

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

由此得到两个信号：

- **IN_LINKED_WORKTREE：** `GIT_DIR != GIT_COMMON`，说明 agent 已经在由其他方创建的 worktree 中（Codex App、Claude Code Agent 工具、此前的技能运行、或用户自己）
- **ON_DETACHED_HEAD：** `BRANCH` 为空，说明当前没有命名分支

为什么用 `git-dir != git-common-dir` 而不是检查 `show-toplevel`：
- 在普通仓库中，这两个路径都会解析到同一个 `.git` 目录
- 在 linked worktree 中，`git-dir` 是 `.git/worktrees/<name>`，而 `git-common-dir` 是 `.git`
- 在 submodule 中，两者相等，这能避免 `show-toplevel` 造成的误判
- 使用 `cd && pwd -P` 解析可同时处理相对路径问题（普通仓库里 `git-common-dir` 会返回相对的 `.git`，而在 worktree 中会返回绝对路径）以及符号链接（macOS 上 `/tmp` → `/private/tmp`）

### 决策矩阵

| Linked Worktree? | Detached HEAD? | 环境 | 动作 |
|---|---|---|---|
| No | No | Claude Code / Codex CLI / 普通 git | 完整技能行为（不变） |
| Yes | Yes | Codex App worktree（workspace-write） | 跳过 worktree 创建；在结束时输出 handoff payload |
| Yes | No | Codex App（Full access）或手动 worktree | 跳过 worktree 创建；执行完整收尾流程 |
| No | Yes | 异常情况（手动 detached HEAD） | 正常创建 worktree；在结束时给出警告 |

## 变更内容

### 1. `using-git-worktrees/SKILL.md`：添加 Step 0（约 12 行）

在 “Overview” 和 “Directory Selection Process” 之间新增一节：

**Step 0：检查是否已经处于隔离工作区**

运行检测命令。如果 `GIT_DIR != GIT_COMMON`，则完全跳过 worktree 创建。改为：
1. 直接跳到 Creation Steps 下的 “Run Project Setup” 子节，执行 `npm install` 等操作。这些命令具有幂等性，值得为安全起见再跑一次
2. 然后执行 “Verify Clean Baseline”，运行测试
3. 依据分支状态进行汇报：
   - 如果在某个分支上："Already in an isolated workspace at `<path>` on branch `<name>`. Tests passing. Ready to implement."
   - 如果是 detached HEAD："Already in an isolated workspace at `<path>` (detached HEAD, externally managed). Tests passing. Note: branch creation needed at finish time. Ready to implement."

如果 `GIT_DIR == GIT_COMMON`，则按原样执行完整 worktree 创建流程。

当 Step 0 生效时，跳过安全校验（`.gitignore` 检查），因为对外部创建的 worktree 来说没有意义。

更新 Integration 部分中的 “Called by” 条目。把每条描述从上下文相关表述改成："Ensures isolated workspace (creates one or verifies existing)"。例如，`subagent-driven-development` 的描述从 "REQUIRED: Set up isolated workspace before starting" 改成 "REQUIRED: Ensures isolated workspace (creates one or verifies existing)"。

**沙箱回退：** 如果 `GIT_DIR == GIT_COMMON`，技能继续进入 Creation Steps，但 `git worktree add -b` 因权限错误失败（例如 Seatbelt 沙箱拒绝），则把它视为一个晚发现的受限环境。此时回退到 Step 0 的“已在工作区中”行为：跳过创建，在当前目录中执行 setup 和 baseline tests，并据此汇报。

在 Step 0 汇报后，**停止**。不要继续进入 Directory Selection 或 Creation Steps。

**其余全部不变：** Directory Selection、Safety Verification、Creation Steps、Project Setup、Baseline Tests、Quick Reference、Common Mistakes、Red Flags。

### 2. `finishing-a-development-branch/SKILL.md`：添加 Step 1.5 + cleanup guard（约 20 行）

**Step 1.5：检测环境**（位于 Step 1 “Verify Tests” 之后、Step 2 “Determine Base Branch” 之前）

运行检测命令。分三条路径：

- **路径 A**：完全跳过 Step 2 和 Step 3（不再确定 base branch，也不展示选项）
- **路径 B 和 C**：照常进入 Step 2（Determine Base Branch）和 Step 3（Present Options）

**路径 A：外部管理的 worktree + detached HEAD**（`GIT_DIR != GIT_COMMON` 且 `BRANCH` 为空）

首先，确保所有工作都已暂存并提交（`git add` + `git commit`）。Codex App 的收尾控件只处理已提交的改动。

然后向用户展示以下内容（**不要**展示四选一菜单）：

```
Implementation complete. All tests passing.
Current HEAD: <full-commit-sha>

This workspace is externally managed (detached HEAD).
I cannot create branches, push, or open PRs from here.

⚠ These commits are on a detached HEAD. If you do not create a branch,
they may be lost when this workspace is cleaned up.

If your host application provides these controls:
- "Create branch" — to name a branch, then commit/push/PR
- "Hand off to local" — to move changes to your local checkout

Suggested branch name: <ticket-id/short-description>
Suggested commit message: <summary-of-work>
```

分支名生成规则：如果有 ticket ID，则使用它（例如 `pri-823/codex-compat`）；否则将 plan 标题的前 5 个词 slugify；再不行就省略该建议。分支名中应避免包含敏感内容（漏洞描述、客户名称等）。

然后跳到 Step 5（对于外部管理的 worktree，cleanup 是 no-op）。

**路径 B：外部管理的 worktree + 命名分支**（`GIT_DIR != GIT_COMMON` 且 `BRANCH` 存在）

照常展示四选一菜单。（Step 5 的 cleanup guard 会再次独立检测外部管理状态。）

**路径 C：普通环境**（`GIT_DIR == GIT_COMMON`）

与当前行为一致，照常展示四选一菜单。

**Step 5 cleanup guard：**

在 cleanup 时重新运行 `GIT_DIR` 与 `GIT_COMMON` 的检测（不要依赖之前的技能输出，收尾技能可能运行在另一个会话中）。如果 `GIT_DIR != GIT_COMMON`，则跳过 `git worktree remove`，因为该工作区归宿主环境所有。

否则，就像现在一样进行检查并移除。注意：现有 Step 5 文案写的是 "For Options 1, 2, 4"，但 Quick Reference 表和 Common Mistakes 一节写的是 "Options 1 & 4 only"。新的 guard 是加在这段既有逻辑之前的，不改变哪些选项会触发 cleanup。

**其余全部不变：** Options 1-4 逻辑、Quick Reference、Common Mistakes、Red Flags。

### 3. `subagent-driven-development/SKILL.md` 和 `executing-plans/SKILL.md`：各改 1 行

这两个技能有一条完全相同的 Integration 部分文案。将其从：
```
- superpowers:using-git-worktrees - REQUIRED: Set up isolated workspace before starting
```
改为：
```
- superpowers:using-git-worktrees - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
```

**其余全部不变：** 派发/审查循环、prompt 模板、模型选择、状态处理、red flags。

### 4. `codex-tools.md`：新增环境检测文档（约 15 行）

在文末新增两节：

**Environment Detection：**

```markdown
## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

\```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
\```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1.5 for how each skill uses these signals.
```

**Codex App Finishing：**

```markdown
## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
```

## 不会变化的内容

- `implementer-prompt.md`、`spec-reviewer-prompt.md`、`code-quality-reviewer-prompt.md`：subagent prompt 不变
- `executing-plans/SKILL.md`：只有 Integration 描述的 1 行变化（与 `subagent-driven-development` 相同）；所有运行时行为都不变
- `dispatching-parallel-agents/SKILL.md`：不涉及 worktree 或收尾操作
- `.codex/INSTALL.md`：安装流程不变
- 四选一收尾菜单：对 Claude Code 和 Codex CLI 原样保留
- 完整的 worktree 创建流程：对非 worktree 环境原样保留
- Subagent 派发/评审/迭代循环：不变（已确认文件系统共享）

## 范围总结

| 文件 | 变更 |
|---|---|
| `skills/using-git-worktrees/SKILL.md` | +12 行（Step 0） |
| `skills/finishing-a-development-branch/SKILL.md` | +20 行（Step 1.5 + cleanup guard） |
| `skills/subagent-driven-development/SKILL.md` | 1 行修改 |
| `skills/executing-plans/SKILL.md` | 1 行修改 |
| `skills/using-superpowers/references/codex-tools.md` | +15 行 |

共新增/修改约 50 行，涉及 5 个文件。无新增文件。无破坏性变更。

## 未来考虑

如果第三个技能也需要同样的检测模式，再把它提取成共享的 `references/environment-detection.md` 文件（方案 B）。目前没有必要，只有 2 个技能会用到它。

## 测试计划

### 自动化测试（实现后在 Claude Code 中运行）

1. 普通仓库检测：断言 `IN_LINKED_WORKTREE=false`
2. Linked worktree 检测：使用 `git worktree add` 创建测试 worktree，断言 `IN_LINKED_WORKTREE=true`
3. Detached HEAD 检测：执行 `git checkout --detach`，断言 `ON_DETACHED_HEAD=true`
4. 收尾技能 handoff 输出：验证在受限环境中输出的是 handoff message，而不是四选一菜单
5. **Step 5 cleanup guard**：创建一个 linked worktree（`git worktree add /tmp/test-cleanup -b test-cleanup`），进入该目录，运行 Step 5 的 cleanup 检测（比较 `GIT_DIR` 与 `GIT_COMMON`），断言它**不会**调用 `git worktree remove`。然后切回主仓库，再执行同样检测，断言它**会**调用 `git worktree remove`。最后清理测试 worktree。

### 手动 Codex App 测试（5 项）

1. Worktree 线程中的检测（workspace-write）：验证 `GIT_DIR != GIT_COMMON` 且 branch 为空
2. Worktree 线程中的检测（Full access）：检测结果相同，但沙箱行为不同
3. 收尾技能 handoff 格式：验证 agent 输出 handoff payload，而不是四选一菜单
4. 完整生命周期：检测 → 提交 → 收尾检测 → 正确行为 → cleanup
5. **Local thread 中的沙箱回退**：启动一个 Codex App **Local thread**（workspace-write sandbox）。提示词："Use the superpowers skill `using-git-worktrees` to set up an isolated workspace for implementing a small change." 预检查：`git checkout -b test-sandbox-check` 应失败并报 `Operation not permitted`。预期行为：技能会检测到 `GIT_DIR == GIT_COMMON`（普通仓库），尝试执行 `git worktree add -b`，遇到 Seatbelt 拒绝后，回退到 Step 0 的“已在工作区中”行为，在当前目录中运行 setup 和 baseline tests，并报告已准备好实现。通过标准：agent 能优雅恢复，不输出晦涩错误。失败标准：agent 打印原始 Seatbelt 错误、反复重试，或以令人困惑的输出放弃。

### 回归

- 现有 Claude Code 技能触发测试仍然通过
- 现有 subagent-driven-development 集成测试仍然通过
- 在普通 Claude Code 会话中，完整 worktree 创建 + 四选一收尾流程仍然可用
