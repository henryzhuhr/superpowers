---
name: writing-plans
description: 在你有一份规范或需求、但还没开始动代码之前使用
---

# 编写计划

## 概述

写出足够完整的实现计划，默认执行者对我们的代码库几乎没有上下文，而且品味也不太可靠。把他们需要知道的全部写清楚：每个任务要改哪些文件、相关代码、要检查哪些测试和文档、如何验证。把整个计划拆成小颗粒任务交给他们。坚持 DRY、YAGNI、TDD，频繁提交。

假设他们是熟练开发者，但对我们的工具集或问题领域几乎一无所知。也假设他们并不擅长好的测试设计。

**开场声明：** `"我正在使用 writing-plans skill 来创建实现计划。"`

**上下文：** 这应该在专用 worktree 中运行（由 brainstorming skill 创建）。

**计划保存到：** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- （如果用户对计划位置有偏好，则以用户偏好为准）

## 范围检查

如果规范覆盖了多个彼此独立的子系统，它本应在 brainstorming 阶段拆成多个子项目规范。若没有拆开，就建议把它拆成多份独立计划，每个子系统一份。每个计划都应该能单独产出可工作的、可测试的软件。

## 文件结构

在定义任务之前，先梳理会创建或修改哪些文件，以及每个文件分别负责什么。这一步会锁定拆分决策。

- 设计有清晰边界、接口明确的单元。每个文件都应该只有一个清晰职责。
- 你最擅长处理能放在上下文里的小代码单元；文件越聚焦，编辑越可靠。优先选择小而专注的文件，不要让一个文件承担太多。
- 需要一起变更的文件应该放在一起。按职责拆分，不要按技术层拆分。
- 在已有代码库里，要遵循既有模式。如果代码库本来就偏大文件，不要擅自重构；但如果你要改的文件已经臃肿，把拆分写进计划是合理的。

这个结构会影响任务拆分。每个任务都应当是自洽的、单独做也说得通的改动。

## 小步任务粒度

**每一步就是一个动作（2-5 分钟）：**
- "写失败测试" - 一步
- "运行它，确认它失败" - 一步
- "实现最小代码让测试通过" - 一步
- "运行测试，确认通过" - 一步
- "提交" - 一步

## 计划文档头部

**每份计划都必须以这个头部开头：**

```markdown
# [Feature Name] Implementation Plan

> **面向代理执行者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实现这份计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**Goal:** [一句话描述这个功能要实现什么]

**Architecture:** [2-3 句描述实现思路]

**Tech Stack:** [关键技术 / 库]

---
```

## 任务结构

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## 不要留占位符

每一步都必须包含工程师真正需要的实际内容。以下都属于**计划失败**，绝对不要写：
- "TBD"、"TODO"、"implement later"、"fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above"（没有具体测试代码）
- "Similar to Task N"（把代码重写一遍，工程师可能是按不同顺序读任务的）
- 只描述要做什么，却不展示怎么做的步骤（涉及代码时必须给出代码块）
- 引用任何在任务里没有定义过的类型、函数或方法

## 记住

- 文件路径必须精确
- 每一步里都要给出完整代码
- 命令必须精确，且要写出预期输出
- DRY、YAGNI、TDD，频繁提交

## 自检

写完完整计划后，用新的眼光重新看一遍规范，对照计划检查。这个检查要你自己执行，不是派给子代理做。

**1. 规范覆盖：** 快速浏览规范的每个部分 / 每项需求。你能指出是哪一个任务实现了它吗？列出任何缺口。

**2. 占位符扫描：** 在你的计划里搜索红旗项，也就是上面 “不要留占位符” 里提到的模式。把它们修掉。

**3. 类型一致性：** 后续任务里使用的类型、方法签名和属性名，是否与前面定义的一致？如果 Task 3 里叫 `clearLayers()`，Task 7 却变成 `clearFullLayers()`，这就是 bug。

如果发现问题，直接在正文里修掉。不需要重新审一遍，修完继续。如果发现某条规范需求还没有对应任务，就补上。

## 交付说明

保存计划后，提供执行方式选择：

**"计划已完成并保存到 `docs/superpowers/plans/<filename>.md`。有两个执行选项：**

**1. 子代理驱动（推荐）** - 我为每个任务派一个新的子代理，任务之间做复审，迭代更快

**2. 直接执行** - 在当前会话里使用 executing-plans 执行，带检查点批量推进

**你选哪一种？**

**如果选择子代理驱动：**
- **必需子技能：** 使用 superpowers:subagent-driven-development
- 每个任务一个新子代理 + 两阶段审查

**如果选择直接执行：**
- **必需子技能：** 使用 superpowers:executing-plans
- 带检查点的批量执行
