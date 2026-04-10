# 文档评审系统设计

## 概览

向 superpowers 工作流中新增两个评审阶段：

1. **Spec 文档评审**：在 brainstorming 之后、writing-plans 之前
2. **Plan 文档评审**：在 writing-plans 之后、implementation 之前

二者都遵循与实现评审相同的迭代循环模式。

## Spec 文档评审者

**目的：** 验证 spec 是否完整、一致，并且已经为实现规划做好准备。

**位置：** `skills/brainstorming/spec-document-reviewer-prompt.md`

**检查内容：**

| 类别 | 检查点 |
|----------|------------------|
| 完整性 | TODO、占位符、"TBD"、未完成章节 |
| 覆盖度 | 缺失的错误处理、边界情况、集成点 |
| 一致性 | 内部矛盾、相互冲突的需求 |
| 清晰度 | 含糊不清的需求 |
| YAGNI | 未被请求的功能、过度设计 |

**输出格式：**
```
## Spec Review

**Status:** Approved | Issues Found

**Issues (if any):**
- [Section X]: [issue] - [why it matters]

**Recommendations (advisory):**
- [suggestions that don't block approval]
```

**评审循环：** 发现问题 -> brainstorming agent 修复 -> 重新评审 -> 重复，直到批准。

**派发机制：** 使用 Task 工具，并设置 `subagent_type: general-purpose`。评审者 prompt 模板会提供完整 prompt。由 brainstorming 技能的控制器派发评审者。

## Plan 文档评审者

**目的：** 验证 plan 是否完整、是否匹配 spec、以及任务拆分是否合理。

**位置：** `skills/writing-plans/plan-document-reviewer-prompt.md`

**检查内容：**

| 类别 | 检查点 |
|----------|------------------|
| 完整性 | TODO、占位符、未完成的任务 |
| 与 Spec 对齐 | 计划覆盖 spec 要求，没有范围蔓延 |
| 任务拆分 | 任务足够原子、边界清晰 |
| 任务语法 | 任务和步骤是否使用 checkbox 语法 |
| Chunk 大小 | 每个 chunk 不超过 1000 行 |

**Chunk 定义：** chunk 是计划文档中任务的逻辑分组，以 `## Chunk N: <name>` 标题划分。writing-plans 技能会根据逻辑阶段（例如 "Foundation"、"Core Features"、"Integration"）创建这些边界。每个 chunk 都应该足够自包含，以便独立评审。

**Spec 对齐校验：** 评审者会收到以下两项内容：
1. 计划文档（或当前 chunk）
2. 用于参考的 spec 文档路径

评审者会读取这两者，并比较需求覆盖情况。

**输出格式：** 与 spec 评审者相同，但范围限定为当前 chunk。

**评审流程（按 chunk 进行）：**
1. Writing-plans 创建 chunk N
2. 控制器将 chunk N 内容和 spec 路径一起派发给 plan-document-reviewer
3. 评审者读取 chunk 和 spec，并返回结论
4. 如果有问题：writing-plans agent 修复 chunk N，然后回到步骤 2
5. 如果已批准：继续处理 chunk N+1
6. 重复以上流程，直到所有 chunk 都批准

**派发机制：** 与 spec 评审者相同，使用带 `subagent_type: general-purpose` 的 Task 工具。

## 更新后的工作流

```
brainstorming -> spec -> SPEC REVIEW LOOP -> writing-plans -> plan -> PLAN REVIEW LOOP -> implementation
```

**Spec 评审循环：**
1. Spec 完成
2. 派发评审者
3. 如果有问题：修复 -> 回到 2
4. 如果已批准：继续

**Plan 评审循环：**
1. Chunk N 完成
2. 为 chunk N 派发评审者
3. 如果有问题：修复 -> 回到 2
4. 如果已批准：进入下一个 chunk 或 implementation

## Markdown 任务语法

任务和步骤使用 checkbox 语法：

```markdown
- [ ] ### Task 1: Name

- [ ] **Step 1:** Description
  - File: path
  - Command: cmd
```

## 错误处理

**评审循环终止：**
- 不设硬性迭代上限，循环会持续直到评审者批准
- 如果循环超过 5 次，控制器应将此情况上报给人工以获取指导
- 人工可以选择：继续迭代、带已知问题批准，或者中止

**分歧处理：**
- 评审者是 advisory 角色，它们会标记问题，但不阻塞流程
- 如果 agent 认为评审反馈不正确，它应在修复中解释原因
- 如果同一问题在 3 次迭代后仍存在分歧，则上报给人工

**评审者输出格式错误：**
- 控制器应验证评审者输出是否包含必需字段（Status，以及适用时的 Issues）
- 如果格式错误，则带上期望格式说明重新派发评审者
- 连续 2 次格式错误后，上报给人工

## 需要修改的文件

**新文件：**
- `skills/brainstorming/spec-document-reviewer-prompt.md`
- `skills/writing-plans/plan-document-reviewer-prompt.md`

**修改的文件：**
- `skills/brainstorming/SKILL.md`：在 spec 写完后添加评审循环
- `skills/writing-plans/SKILL.md`：按 chunk 添加评审循环，并更新任务语法示例
