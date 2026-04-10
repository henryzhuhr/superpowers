# 文档评审系统实施计划

> **For agentic workers:** REQUIRED: 使用 superpowers:subagent-driven-development（如果有 subagent）或 superpowers:executing-plans 来实现本计划。

**Goal:** 向 brainstorming 和 writing-plans 技能添加 spec 与 plan 文档评审循环。

**Architecture:** 在各技能目录中创建 reviewer prompt 模板。修改技能文件，在文档创建后加入评审循环。使用 Task 工具搭配 general-purpose subagent 来派发 reviewer。

**Tech Stack:** Markdown 技能文件，通过 Task 工具派发 subagent

**Spec:** docs/superpowers/specs/2026-01-22-document-review-system-design.md

---

## Chunk 1：Spec 文档评审者

这个 chunk 为 brainstorming 技能添加 spec 文档评审者。

### Task 1：创建 Spec 文档评审 Prompt 模板

**Files:**
- Create: `skills/brainstorming/spec-document-reviewer-prompt.md`

- [ ] **Step 1:** 创建 reviewer prompt 模板文件

```markdown
# Spec Document Reviewer Prompt Template

在派发 spec 文档评审 subagent 时使用此模板。

**Purpose:** 验证 spec 是否完整、一致，并为 implementation planning 做好准备。

**Dispatch after:** spec 文档写入 docs/superpowers/specs/ 之后

```
Task tool (general-purpose):
  description: "Review spec document"
  prompt: |
    You are a spec document reviewer. Verify this spec is complete and ready for planning.

    **Spec to review:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, "TBD", incomplete sections |
    | Coverage | Missing error handling, edge cases, integration points |
    | Consistency | Internal contradictions, conflicting requirements |
    | Clarity | Ambiguous requirements |
    | YAGNI | Unrequested features, over-engineering |

    ## CRITICAL

    Look especially hard for:
    - Any TODO markers or placeholder text
    - Sections saying "to be defined later" or "will spec when X is done"
    - Sections noticeably less detailed than others

    ## Output Format

    ## Spec Review

    **Status:** ✅ Approved | ❌ Issues Found

    **Issues (if any):**
    - [Section X]: [specific issue] - [why it matters]

    **Recommendations (advisory):**
    - [suggestions that don't block approval]
```

**Reviewer returns:** Status、Issues（如果有）、Recommendations
```

- [ ] **Step 2:** 验证文件已正确创建

运行：`cat skills/brainstorming/spec-document-reviewer-prompt.md | head -20`
预期：显示标题和 purpose 部分

- [ ] **Step 3:** 提交

```bash
git add skills/brainstorming/spec-document-reviewer-prompt.md
git commit -m "feat: add spec document reviewer prompt template"
```

---

### Task 2：为 Brainstorming 技能添加评审循环

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1:** 读取当前 brainstorming 技能

运行：`cat skills/brainstorming/SKILL.md`

- [ ] **Step 2:** 在 “After the Design” 后添加评审循环章节

找到 “After the Design” 一节，在文档说明之后、implementation 之前插入一个新的 “Spec Review Loop” 章节：

```markdown
**Spec Review Loop:**
在写完 spec 文档之后：
1. 派发 spec-document-reviewer subagent（见 spec-document-reviewer-prompt.md）
2. 如果 ❌ Issues Found：
   - 修复 spec 文档中的问题
   - 重新派发 reviewer
   - 重复直到 ✅ Approved
3. 如果 ✅ Approved：继续 implementation setup

**Review loop guidance:**
- 由写 spec 的同一个 agent 负责修复（保留上下文）
- 如果循环超过 5 次，上报给人工获取指导
- Reviewers 是 advisory 角色，如果你认为反馈不正确，应解释分歧原因
```

- [ ] **Step 3:** 验证变更

运行：`grep -A 15 "Spec Review Loop" skills/brainstorming/SKILL.md`
预期：显示新增的 review loop 章节

- [ ] **Step 4:** 提交

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat: add spec review loop to brainstorming skill"
```

---

## Chunk 2：Plan 文档评审者

这个 chunk 为 writing-plans 技能添加 plan 文档评审者。

### Task 3：创建 Plan 文档评审 Prompt 模板

**Files:**
- Create: `skills/writing-plans/plan-document-reviewer-prompt.md`

- [ ] **Step 1:** 创建 reviewer prompt 模板文件

```markdown
# Plan Document Reviewer Prompt Template

在派发 plan 文档评审 subagent 时使用此模板。

**Purpose:** 验证 plan chunk 是否完整、是否匹配 spec，以及任务拆分是否合理。

**Dispatch after:** 每个 plan chunk 写完之后

```
Task tool (general-purpose):
  description: "Review plan chunk N"
  prompt: |
    You are a plan document reviewer. Verify this plan chunk is complete and ready for implementation.

    **Plan chunk to review:** [PLAN_FILE_PATH] - Chunk N only
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Chunk covers relevant spec requirements, no scope creep |
    | Task Decomposition | Tasks atomic, clear boundaries, steps actionable |
    | Task Syntax | Checkbox syntax (`- [ ]`) on tasks and steps |
    | Chunk Size | Each chunk under 1000 lines |

    ## CRITICAL

    Look especially hard for:
    - Any TODO markers or placeholder text
    - Steps that say "similar to X" without actual content
    - Incomplete task definitions
    - Missing verification steps or expected outputs

    ## Output Format

    ## Plan Review - Chunk N

    **Status:** ✅ Approved | ❌ Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] - [why it matters]

    **Recommendations (advisory):**
    - [suggestions that don't block approval]
```

**Reviewer returns:** Status、Issues（如果有）、Recommendations
```

- [ ] **Step 2:** 验证文件已创建

运行：`cat skills/writing-plans/plan-document-reviewer-prompt.md | head -20`
预期：显示标题和 purpose 部分

- [ ] **Step 3:** 提交

```bash
git add skills/writing-plans/plan-document-reviewer-prompt.md
git commit -m "feat: add plan document reviewer prompt template"
```

---

### Task 4：为 Writing-Plans 技能添加评审循环

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1:** 读取当前技能文件

运行：`cat skills/writing-plans/SKILL.md`

- [ ] **Step 2:** 添加按 chunk 进行的评审章节

在 “Execution Handoff” 一节之前添加：

```markdown
## Plan Review Loop

每完成一个 chunk 后：

1. 为当前 chunk 派发 plan-document-reviewer subagent
   - 提供：chunk 内容、spec 文档路径
2. 如果 ❌ Issues Found：
   - 修复该 chunk 中的问题
   - 为该 chunk 重新派发 reviewer
   - 重复直到 ✅ Approved
3. 如果 ✅ Approved：继续下一个 chunk（如果是最后一个 chunk，则进入 execution handoff）

**Chunk boundaries:** 使用 `## Chunk N: <name>` 标题划分 chunk。每个 chunk 应 ≤1000 行，并且在逻辑上自包含。
```

- [ ] **Step 3:** 更新任务语法示例为 checkbox 形式

把 Task Structure 一节改为显示 checkbox 语法：

```markdown
### Task N: [Component Name]

- [ ] **Step 1:** 编写失败测试
  - File: `tests/path/test.py`
  ...
```

- [ ] **Step 4:** 验证已添加 review loop 章节

运行：`grep -A 15 "Plan Review Loop" skills/writing-plans/SKILL.md`
预期：显示新增的 review loop 章节

- [ ] **Step 5:** 验证任务语法示例已更新

运行：`grep -A 5 "Task N:" skills/writing-plans/SKILL.md`
预期：显示 checkbox 语法 `### Task N:`

- [ ] **Step 6:** 提交

```bash
git add skills/writing-plans/SKILL.md
git commit -m "feat: add plan review loop and checkbox syntax to writing-plans skill"
```

---

## Chunk 3：更新 Plan 文档头模板

这个 chunk 更新 plan 文档头模板，使其引用新的 checkbox 语法要求。

### Task 5：更新 Writing-Plans 技能中的计划头模板

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1:** 读取当前 plan 头模板

运行：`grep -A 20 "Plan Document Header" skills/writing-plans/SKILL.md`

- [ ] **Step 2:** 更新头模板，注明 checkbox 语法

计划头应说明任务和步骤使用 checkbox 语法。将头部注释更新为：

```markdown
> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Tasks and steps use checkbox (`- [ ]`) syntax for tracking.
```

- [ ] **Step 3:** 验证变更

运行：`grep -A 5 "For agentic workers:" skills/writing-plans/SKILL.md`
预期：显示更新后的头部，包含 checkbox 语法说明

- [ ] **Step 4:** 提交

```bash
git add skills/writing-plans/SKILL.md
git commit -m "docs: update plan header to reference checkbox syntax"
```
