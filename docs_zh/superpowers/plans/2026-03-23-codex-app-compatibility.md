# Codex App 兼容性实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐项实现本计划。步骤使用 checkbox（`- [ ]`）语法进行跟踪。

**Goal:** 让 `using-git-worktrees`、`finishing-a-development-branch` 及相关技能能在 Codex App 的沙箱 worktree 环境中运行，同时不破坏现有行为。

**Architecture:** 在两个技能开头添加只读环境检测（`git-dir` vs `git-common-dir`）。如果已经在 linked worktree 中，则跳过创建。如果处于 detached HEAD，则输出 handoff payload，而不是展示四选一菜单。worktree 创建期间的权限错误由 sandbox fallback 兜底。

**Tech Stack:** Git、Markdown（skill 文件是说明文档，不是可执行代码）

**Spec:** `docs/superpowers/specs/2026-03-23-codex-app-compatibility-design.md`

---

## 文件结构

| 文件 | 责任 | 动作 |
|---|---|---|
| `skills/using-git-worktrees/SKILL.md` | Worktree 创建与隔离 | 添加 Step 0 检测 + sandbox fallback |
| `skills/finishing-a-development-branch/SKILL.md` | 分支收尾工作流 | 添加 Step 1.5 检测 + cleanup guard |
| `skills/subagent-driven-development/SKILL.md` | 使用 subagent 执行计划 | 更新 Integration 描述 |
| `skills/executing-plans/SKILL.md` | 内联执行计划 | 更新 Integration 描述 |
| `skills/using-superpowers/references/codex-tools.md` | Codex 平台参考 | 添加检测 + 收尾文档 |

---

### Task 1：为 `using-git-worktrees` 添加 Step 0

**Files:**
- Modify: `skills/using-git-worktrees/SKILL.md:14-15`（插入在 Overview 之后、Directory Selection Process 之前）

- [ ] **Step 1: 读取当前技能文件**

完整读取 `skills/using-git-worktrees/SKILL.md`。确认准确插入点：位于 “Announce at start” 这一行（第 14 行）之后、`## Directory Selection Process`（第 16 行）之前。

- [ ] **Step 2: 插入 Step 0 章节**

在 Overview 和 `## Directory Selection Process` 之间插入以下内容：

```markdown
## Step 0: Check if Already in an Isolated Workspace

Before creating a worktree, check if one already exists:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**If `GIT_DIR` differs from `GIT_COMMON`:** You are already inside a linked worktree (created by the Codex App, Claude Code's Agent tool, a previous skill run, or the user). Do NOT create another worktree. Instead:

1. Run project setup (auto-detect package manager as in "Run Project Setup" below)
2. Verify clean baseline (run tests as in "Verify Clean Baseline" below)
3. Report with branch state:
   - On a branch: "Already in an isolated workspace at `<path>` on branch `<name>`. Tests passing. Ready to implement."
   - Detached HEAD: "Already in an isolated workspace at `<path>` (detached HEAD, externally managed). Tests passing. Note: branch creation needed at finish time. Ready to implement."

After reporting, STOP. Do not continue to Directory Selection or Creation Steps.

**If `GIT_DIR` equals `GIT_COMMON`:** Proceed with the full worktree creation flow below.

**Sandbox fallback:** If you proceed to Creation Steps but `git worktree add -b` fails with a permission error (e.g., "Operation not permitted"), treat this as a late-detected restricted environment. Fall back to the behavior above — run setup and baseline tests in the current directory, report accordingly, and STOP.
```

- [ ] **Step 3: 验证插入结果**

再次读取文件。确认：
- Step 0 位于 Overview 与 Directory Selection Process 之间
- 文件其他部分（Directory Selection、Safety Verification、Creation Steps 等）保持不变
- 没有重复章节，也没有损坏的 markdown

- [ ] **Step 4: 提交**

```bash
git add skills/using-git-worktrees/SKILL.md
git commit -m "feat(using-git-worktrees): add Step 0 environment detection (PRI-823)

Skip worktree creation when already in a linked worktree. Includes
sandbox fallback for permission errors on git worktree add."
```

---

### Task 2：更新 `using-git-worktrees` 的 Integration 章节

**Files:**
- Modify: `skills/using-git-worktrees/SKILL.md:211-215`（Integration > Called by）

- [ ] **Step 1: 更新三条 “Called by” 项**

把第 212-214 行从：

```markdown
- **brainstorming** (Phase 4) - REQUIRED when design is approved and implementation follows
- **subagent-driven-development** - REQUIRED before executing any tasks
- **executing-plans** - REQUIRED before executing any tasks
```

改为：

```markdown
- **brainstorming** - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
- **subagent-driven-development** - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
- **executing-plans** - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
```

- [ ] **Step 2: 验证 Integration 章节**

读取 Integration 章节。确认三条都已更新，`Pairs with` 保持不变。

- [ ] **Step 3: 提交**

```bash
git add skills/using-git-worktrees/SKILL.md
git commit -m "docs(using-git-worktrees): update Integration descriptions (PRI-823)

Clarify that skill ensures a workspace exists, not that it always creates one."
```

---

### Task 3：为 `finishing-a-development-branch` 添加 Step 1.5

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md:38`（插入在 Step 1 后、Step 2 前）

- [ ] **Step 1: 读取当前技能文件**

完整读取 `skills/finishing-a-development-branch/SKILL.md`。确认插入点：位于 “**If tests pass:** Continue to Step 2.”（第 38 行）之后、`### Step 2: Determine Base Branch`（第 40 行）之前。

- [ ] **Step 2: 插入 Step 1.5 章节**

在 Step 1 和 Step 2 之间插入以下内容：

```markdown
### Step 1.5: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

**Path A — `GIT_DIR` differs from `GIT_COMMON` AND `BRANCH` is empty (externally managed worktree, detached HEAD):**

First, ensure all work is staged and committed (`git add` + `git commit`).

Then present this to the user (do NOT present the 4-option menu):

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

Branch name: use ticket ID if available (e.g., `pri-823/codex-compat`), otherwise slugify the first 5 words of the plan title, otherwise omit. Avoid sensitive content in branch names.

Skip to Step 5 (cleanup is a no-op — see guard below).

**Path B — `GIT_DIR` differs from `GIT_COMMON` AND `BRANCH` exists (externally managed worktree, named branch):**

Proceed to Step 2 and present the 4-option menu as normal.

**Path C — `GIT_DIR` equals `GIT_COMMON` (normal environment):**

Proceed to Step 2 and present the 4-option menu as normal.
```

- [ ] **Step 3: 验证插入结果**

再次读取文件。确认：
- Step 1.5 位于 Step 1 与 Step 2 之间
- Steps 2-5 保持不变
- Path A 的 handoff 包含 commit SHA 和数据丢失警告
- Paths B 和 C 都正常进入 Step 2

- [ ] **Step 4: 提交**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(finishing-a-development-branch): add Step 1.5 environment detection (PRI-823)

Detect externally managed worktrees with detached HEAD and emit handoff
payload instead of 4-option menu. Includes commit SHA and data loss warning."
```

---

### Task 4：为 `finishing-a-development-branch` 添加 Step 5 cleanup guard

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`（Step 5: Cleanup Worktree，Task 3 插入后行号会变化，按标题查找）

- [ ] **Step 1: 读取当前 Step 5 章节**

在 `skills/finishing-a-development-branch/SKILL.md` 中找到 “### Step 5: Cleanup Worktree” 章节（Task 3 插入后行号会变化）。当前 Step 5 为：

```markdown
### Step 5: Cleanup Worktree

**For Options 1, 2, 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.
```

- [ ] **Step 2: 在现有逻辑前添加 cleanup guard**

把 Step 5 章节替换为：

```markdown
### Step 5: Cleanup Worktree

**First, check if worktree is externally managed:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

If `GIT_DIR` differs from `GIT_COMMON`: skip worktree removal — the host environment owns this workspace.

**Otherwise, for Options 1 and 4:**

Check if in worktree:
```bash
git worktree list | grep $(git branch --show-current)
```

If yes:
```bash
git worktree remove <worktree-path>
```

**For Option 3:** Keep worktree.
```

注意：原文写的是 “For Options 1, 2, 4”，但 Quick Reference 表和 Common Mistakes 一节都写的是 “Options 1 & 4 only”。这次修改会让 Step 5 与那些章节保持一致。

- [ ] **Step 3: 验证替换结果**

读取 Step 5。确认：
- cleanup guard（重新检测）位于最前面
- 对非外部管理 worktree 的移除逻辑被保留
- “Options 1 and 4”（而不是 “1, 2, 4”）与 Quick Reference 和 Common Mistakes 一致

- [ ] **Step 4: 提交**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "feat(finishing-a-development-branch): add Step 5 cleanup guard (PRI-823)

Re-detect externally managed worktree at cleanup time and skip removal.
Also fixes pre-existing inconsistency: cleanup now correctly says
Options 1 and 4 only, matching Quick Reference and Common Mistakes."
```

---

### Task 5：更新 `subagent-driven-development` 与 `executing-plans` 中的 Integration 文案

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md:268`
- Modify: `skills/executing-plans/SKILL.md:68`

- [ ] **Step 1: 更新 `subagent-driven-development`**

把第 268 行从：
```
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
```
改为：
```
- **superpowers:using-git-worktrees** - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
```

- [ ] **Step 2: 更新 `executing-plans`**

把第 68 行从：
```
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
```
改为：
```
- **superpowers:using-git-worktrees** - REQUIRED: Ensures isolated workspace (creates one or verifies existing)
```

- [ ] **Step 3: 验证两个文件**

读取 `skills/subagent-driven-development/SKILL.md` 的第 268 行和 `skills/executing-plans/SKILL.md` 的第 68 行。确认两处都写成了 "Ensures isolated workspace (creates one or verifies existing)"。

- [ ] **Step 4: 提交**

```bash
git add skills/subagent-driven-development/SKILL.md skills/executing-plans/SKILL.md
git commit -m "docs(sdd, executing-plans): update worktree Integration descriptions (PRI-823)

Clarify that using-git-worktrees ensures a workspace exists rather than
always creating one."
```

---

### Task 6：向 `codex-tools.md` 添加环境检测文档

**Files:**
- Modify: `skills/using-superpowers/references/codex-tools.md:25`（追加到文件末尾）

- [ ] **Step 1: 读取当前文件**

完整读取 `skills/using-superpowers/references/codex-tools.md`。确认它在 multi_agent 一节后于第 25-26 行结束。

- [ ] **Step 2: 追加两个新章节**

在文件末尾添加：

```markdown

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1.5 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
```

- [ ] **Step 3: 验证新增内容**

完整读取文件。确认：
- 两个新章节出现在现有内容之后
- Bash 代码块能正确渲染（没有被错误转义）
- 存在对 Step 0 和 Step 1.5 的交叉引用

- [ ] **Step 4: 提交**

```bash
git add skills/using-superpowers/references/codex-tools.md
git commit -m "docs(codex-tools): add environment detection and App finishing docs (PRI-823)

Document the git-dir vs git-common-dir detection pattern and the Codex
App's native finishing flow for skills that need to adapt."
```

---

### Task 7：自动化测试，验证环境检测

**Files:**
- Create: `tests/codex-app-compat/test-environment-detection.sh`

- [ ] **Step 1: 创建测试目录**

```bash
mkdir -p tests/codex-app-compat
```

- [ ] **Step 2: 编写检测测试脚本**

创建 `tests/codex-app-compat/test-environment-detection.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test environment detection logic from PRI-823
# Tests the git-dir vs git-common-dir comparison used by
# using-git-worktrees Step 0 and finishing-a-development-branch Step 1.5

PASS=0
FAIL=0
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Helper: run detection and return "linked" or "normal"
detect_worktree() {
  local git_dir git_common
  git_dir=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
  git_common=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
  if [ "$git_dir" != "$git_common" ]; then
    echo "linked"
  else
    echo "normal"
  fi
}

echo "=== Test 1: Normal repo detection ==="
cd "$TEMP_DIR"
git init test-repo > /dev/null 2>&1
cd test-repo
git commit --allow-empty -m "init" > /dev/null 2>&1
result=$(detect_worktree)
if [ "$result" = "normal" ]; then
  log_pass "Normal repo detected as normal"
else
  log_fail "Normal repo detected as '$result' (expected 'normal')"
fi

echo "=== Test 2: Linked worktree detection ==="
git worktree add "$TEMP_DIR/test-wt" -b test-branch > /dev/null 2>&1
cd "$TEMP_DIR/test-wt"
result=$(detect_worktree)
if [ "$result" = "linked" ]; then
  log_pass "Linked worktree detected as linked"
else
  log_fail "Linked worktree detected as '$result' (expected 'linked')"
fi

echo "=== Test 3: Detached HEAD detection ==="
git checkout --detach HEAD > /dev/null 2>&1
branch=$(git branch --show-current)
if [ -z "$branch" ]; then
  log_pass "Detached HEAD: branch is empty"
else
  log_fail "Detached HEAD: branch is '$branch' (expected empty)"
fi

echo "=== Test 4: Linked worktree + detached HEAD (Codex App simulation) ==="
result=$(detect_worktree)
branch=$(git branch --show-current)
if [ "$result" = "linked" ] && [ -z "$branch" ]; then
  log_pass "Codex App simulation: linked + detached HEAD"
else
  log_fail "Codex App simulation: result='$result', branch='$branch'"
fi

echo "=== Test 5: Cleanup guard — linked worktree should NOT remove ==="
cd "$TEMP_DIR/test-wt"
result=$(detect_worktree)
if [ "$result" = "linked" ]; then
  log_pass "Cleanup guard: linked worktree correctly detected (would skip removal)"
else
  log_fail "Cleanup guard: expected 'linked', got '$result'"
fi

echo "=== Test 6: Cleanup guard — main repo SHOULD remove ==="
cd "$TEMP_DIR/test-repo"
result=$(detect_worktree)
if [ "$result" = "normal" ]; then
  log_pass "Cleanup guard: main repo correctly detected (would proceed with removal)"
else
  log_fail "Cleanup guard: expected 'normal', got '$result'"
fi

# Cleanup worktree before temp dir removal
cd "$TEMP_DIR/test-repo"
git worktree remove "$TEMP_DIR/test-wt" > /dev/null 2>&1 || true

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

- [ ] **Step 3: 赋予可执行权限并运行**

```bash
chmod +x tests/codex-app-compat/test-environment-detection.sh
./tests/codex-app-compat/test-environment-detection.sh
```

预期输出：6 passed，0 failed。

- [ ] **Step 4: 提交**

```bash
git add tests/codex-app-compat/test-environment-detection.sh
git commit -m "test: add environment detection tests for Codex App compat (PRI-823)

Tests git-dir vs git-common-dir comparison in normal repo, linked
worktree, detached HEAD, and cleanup guard scenarios."
```

---

### Task 8：最终验证

**Files:**
- Read: 所有 5 个被修改的 skill 文件

- [ ] **Step 1: 运行自动化检测测试**

```bash
./tests/codex-app-compat/test-environment-detection.sh
```

预期：6 passed，0 failed。

- [ ] **Step 2: 逐个读取被修改文件并验证变更**

逐个端到端读取：
- `skills/using-git-worktrees/SKILL.md`：存在 Step 0，其余部分不变
- `skills/finishing-a-development-branch/SKILL.md`：存在 Step 1.5，存在 cleanup guard，其余部分不变
- `skills/subagent-driven-development/SKILL.md`：第 268 行已更新
- `skills/executing-plans/SKILL.md`：第 68 行已更新
- `skills/using-superpowers/references/codex-tools.md`：末尾新增两个章节

- [ ] **Step 3: 验证没有意外改动**

```bash
git diff --stat HEAD~7
```

应该只显示 6 个文件有变更（5 个 skill 文件 + 1 个测试文件）。不应有其他文件被修改。

- [ ] **Step 4: 运行现有测试套件**

如果存在测试运行器：
```bash
# 运行 skill-triggering 测试
./tests/skill-triggering/run-all.sh 2>/dev/null || echo "Skill triggering tests not available in this environment"

# 运行 SDD 集成测试
./tests/claude-code/test-subagent-driven-development-integration.sh 2>/dev/null || echo "SDD integration test not available in this environment"
```

注意：这些测试需要 Claude Code 并带 `--dangerously-skip-permissions`。如果当前环境不可用，请记录回归测试需手动运行。
