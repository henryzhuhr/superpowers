---
name: executing-plans
description: 适用于你手头已经有一份书面实施计划，需要在独立会话中带着审查检查点去执行它的场景
---

# 执行计划

## 概览

加载计划，批判性审查，执行所有任务，完成后报告。

**开始时先声明：** "I'm using the executing-plans skill to implement this plan."

**注意：** 告诉你的人类协作方，Superpowers 在能访问子代理时效果会好得多。如果在支持子代理的平台上运行（例如 Claude Code 或 Codex），它的工作质量会显著更高。如果可以使用子代理，请改用 `superpowers:subagent-driven-development`，不要使用这个技能。

## 流程

### 第 1 步：加载并审查计划
1. 读取计划文件
2. 批判性审查 - 识别计划中的任何疑问或顾虑
3. 如果有顾虑：在开始前先向你的人类协作方提出
4. 如果没有顾虑：创建 TodoWrite 并继续

### 第 2 步：执行任务

对每个任务：
1. 标记为 `in_progress`
2. 严格按照每一步执行（计划应当是足够细小的步骤）
3. 按照计划要求运行验证
4. 标记为 `completed`

### 第 3 步：完成开发

所有任务完成并通过验证后：
- 声明："`I'm using the finishing-a-development-branch skill to complete this work.`"
- **必需的子技能：** 使用 `superpowers:finishing-a-development-branch`
- 按照该技能执行验证测试、呈现选项、执行所选方案

## 何时停止并寻求帮助

**在以下情况发生时，立即停止执行：**
- 遇到阻塞（缺少依赖、测试失败、指令不清楚）
- 计划存在阻止开始的关键缺口
- 你不理解某条指令
- 验证反复失败

**如果有疑问，先请求澄清，不要猜。**

## 何时回到前面的步骤

**在以下情况返回“审查”（第 1 步）：**
- 你的人类协作方根据你的反馈更新了计划
- 需要重新思考根本方案

**不要强行推进阻塞** - 停下来并提问。

## 记住
- 先批判性审查计划
- 严格遵循计划步骤
- 不要跳过验证
- 计划要求引用哪些技能，就引用哪些技能
- 遇到阻塞就停止，不要猜
- 未经明确允许，不要在 `main/master` 分支上开始实现

## 集成

**必需的工作流技能：**
- **superpowers:using-git-worktrees** - 必需：在开始前建立隔离工作区
- **superpowers:writing-plans** - 创建本技能执行的计划
- **superpowers:finishing-a-development-branch** - 在所有任务完成后收尾开发
