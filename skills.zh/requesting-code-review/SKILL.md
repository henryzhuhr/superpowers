---
name: requesting-code-review
description: 在完成任务、实现重大功能，或在合并前使用，以验证工作是否满足要求
---

# 请求代码审查

调用 `superpowers:code-reviewer` 子代理，在问题扩散前把它们捕捉出来。审查者会接收专门整理过的评审上下文，而不是你这段会话的历史。这样可以让审查者专注于产出物，而不是你的思路，同时保留你自己的上下文，便于继续工作。

**核心原则：** 尽早审查，频繁审查。

## 何时请求审查

**强制：**
- 在子代理驱动开发中的每个任务之后
- 完成重大功能之后
- 合并到 `main` 之前

**可选但很有价值：**
- 卡住时（换个视角）
- 重构前（做基线检查）
- 修复复杂 bug 之后

## 如何请求

**1. 获取 git SHA：**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # 或 origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. 派发 code-reviewer 子代理：**

使用 Task 工具，类型设为 `superpowers:code-reviewer`，并填写 `code-reviewer.md` 中的模板

**占位符：**
- `{WHAT_WAS_IMPLEMENTED}` - 你刚刚构建了什么
- `{PLAN_OR_REQUIREMENTS}` - 它应该做什么
- `{BASE_SHA}` - 起始提交
- `{HEAD_SHA}` - 结束提交
- `{DESCRIPTION}` - 简要说明

**3. 根据反馈采取行动：**
- 立即修复 Critical 问题
- 在继续之前修复 Important 问题
- 记录 Minor 问题，留待以后处理
- 如果审查者错了，要用理由反驳

## 示例

```
[刚完成任务 2：添加验证函数]

你：让我先请求代码审查，再继续。

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[派发 superpowers:code-reviewer 子代理]
  WHAT_WAS_IMPLEMENTED: Conversation index 的验证和修复函数
  PLAN_OR_REQUIREMENTS: docs/superpowers/plans/deployment-plan.md 中的任务 2
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: 添加了 verifyIndex() 和 repairIndex()，包含 4 类问题

[子代理返回]:
  优点: 架构清晰，测试真实
  问题:
    Important: 缺少进度指示器
    Minor: 报告间隔使用了魔法数字（100）
  评估: 可以继续

你：[修复进度指示器]
[继续执行任务 3]
```

## 与工作流集成

**子代理驱动开发：**
- 每个任务后都审查
- 在问题累积前把它们捕捉出来
- 在进入下一个任务前修复

**执行计划：**
- 每批（3 个任务）后审查
- 获取反馈，应用，继续

**临时开发：**
- 合并前审查
- 卡住时审查

## 红旗

**永远不要：**
- 因为“很简单”就跳过审查
- 忽略 Critical 问题
- 带着未修复的 Important 问题继续推进
- 对有效的技术反馈争辩不休

**如果审查者错了：**
- 用技术理由反驳
- 展示能证明它工作的代码/测试
- 请求澄清

模板见：`requesting-code-review/code-reviewer.md`
