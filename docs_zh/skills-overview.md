# Superpowers Skills 总览

本文档说明 `skills/` 目录下每个 skill 的用途、核心功能、适用场景，以及它们之间的大致关系。

## 整体结构

这些 skill 大致可以分为 5 类：

1. **入口与调度**
   - `using-superpowers`
   - `dispatching-parallel-agents`

2. **需求到实现的主流程**
   - `brainstorming`
   - `writing-plans`
   - `subagent-driven-development`
   - `executing-plans`
   - `finishing-a-development-branch`
   - `using-git-worktrees`

3. **质量保障与开发纪律**
   - `test-driven-development`
   - `systematic-debugging`
   - `verification-before-completion`
   - `requesting-code-review`
   - `receiving-code-review`

4. **技能体系自身维护**
   - `writing-skills`

## 常见工作流

最典型的主流程是：

1. 先用 `using-superpowers` 确认应该先找 skill 再动手。
2. 有新需求或行为变更时，先用 `brainstorming` 做设计澄清。
3. 设计批准后，用 `writing-plans` 写实施计划。
4. 实施前用 `using-git-worktrees` 建立隔离工作区。
5. 如果平台支持 subagent，优先用 `subagent-driven-development` 按任务执行。
6. 如果不在当前会话里执行，或不能方便使用 subagent，则用 `executing-plans`。
7. 实施过程中配合 `test-driven-development`、`systematic-debugging`、`requesting-code-review`、`receiving-code-review`、`verification-before-completion` 保证质量。
8. 完成后用 `finishing-a-development-branch` 做收尾、合并、PR 或清理。

## Skill 明细

### `using-superpowers`

**作用：**
这是总入口 skill，定义“只要有可能适用 skill，就必须先用 skill”的规则。

**核心功能：**
- 规定 skill 的调用优先级和使用纪律。
- 要求在任何响应或行动前，先判断是否需要调用相关 skill。
- 说明不同平台如何访问和加载 skill。
- 约束其他 skill 的使用顺序，尤其是先设计、后实现。

**适用场景：**
- 任意新对话开始时。
- 不确定该用哪个 skill 时。
- 需要判断“先回答问题还是先调 skill”时。

### `brainstorming`

**作用：**
在任何创意性工作、功能新增、行为修改之前，先把想法收敛成明确设计。

**核心功能：**
- 先探索项目上下文，再逐步澄清需求。
- 一次只问一个问题，理解目标、约束和成功标准。
- 提出 2 到 3 个方案并比较取舍。
- 输出设计说明，并要求用户批准。
- 把设计写入 `docs/superpowers/specs/`。
- 在设计通过后，交给 `writing-plans` 继续。

**适用场景：**
- 新功能设计。
- 组件或交互改造。
- 任意需要先定方案、再写代码的任务。

### `writing-plans`

**作用：**
把 spec 或需求文档转成可执行的 implementation plan。

**核心功能：**
- 要求先明确文件结构和职责边界。
- 把任务拆成足够细的小步骤。
- 强调 DRY、YAGNI、TDD、频繁提交。
- 生成统一格式的计划文档，保存到 `docs/superpowers/plans/`。
- 为后续执行 skill 提供标准输入。

**适用场景：**
- 设计已经批准，需要进入实现阶段。
- 任务较大、需要分步骤执行。
- 需要让低上下文执行者也能照计划推进。

### `using-git-worktrees`

**作用：**
在开始功能开发或执行实施计划之前，创建隔离的 git worktree 工作区。

**核心功能：**
- 自动选择 worktree 目录位置。
- 检查 `.gitignore` 与目录安全性。
- 创建隔离分支/工作目录。
- 自动执行项目初始化命令和基线测试。
- 避免直接在当前主工作区上动手。

**适用场景：**
- 任何中大型功能开发开始前。
- 需要与当前工作目录隔离的修改。
- 与 `writing-plans`、`subagent-driven-development`、`executing-plans` 配合时。

### `subagent-driven-development`

**作用：**
在当前会话内，基于实施计划把独立任务分派给 fresh subagent 执行，并在每个任务后做双阶段审查。

**核心功能：**
- 每个任务派一个新的 implementer subagent。
- 先做 spec compliance review，再做 code quality review。
- 保持主会话专注于协调，不把历史上下文全部塞给子任务。
- 支持在任务级别循环修正，直到通过审查。
- 适合高并行、高质量执行。

**适用场景：**
- 已有 implementation plan。
- 任务之间大多独立。
- 平台支持 subagent。
- 希望在同一会话内快速推进多个任务。

### `executing-plans`

**作用：**
按已有实施计划逐项执行，适用于独立会话或不使用 subagent 的场景。

**核心功能：**
- 先完整读取并批判性审查计划。
- 严格按步骤执行任务与验证。
- 遇到阻塞时立即停下并求助，而不是猜。
- 完成后交给 `finishing-a-development-branch` 做收尾。

**适用场景：**
- 已有书面计划，但不在适合并行 subagent 的环境里。
- 需要单线程、顺序执行。
- 需要和 `subagent-driven-development` 区分使用场景时。

### `finishing-a-development-branch`

**作用：**
在实现完成、测试通过后，指导如何合并、提 PR、保留分支或丢弃工作。

**核心功能：**
- 强制先验证测试通过。
- 确定 base branch。
- 向用户展示标准化的收尾选项。
- 执行 merge、push/PR、保留、丢弃等流程。
- 在需要时清理 worktree。

**适用场景：**
- 一个实施阶段完成之后。
- 准备合并或提交 PR 时。
- 需要标准化结束开发分支的流程时。

### `dispatching-parallel-agents`

**作用：**
当存在多个互不依赖的问题域时，把它们并行分派给不同 agent。

**核心功能：**
- 识别哪些问题彼此独立。
- 为每个问题域构造聚焦的 agent prompt。
- 并发派发多个 agent。
- 汇总并整合多个 agent 的结果。

**适用场景：**
- 多个测试文件独立失败。
- 多个子系统同时出问题，但互不依赖。
- 并行调查比串行更划算时。

### `test-driven-development`

**作用：**
把 TDD 作为功能开发和 bugfix 的默认方式。

**核心功能：**
- 强制遵守“先写失败测试，再写最小实现”。
- 明确 RED-GREEN-REFACTOR 循环。
- 约束“看见测试先失败”这一关键动作。
- 提供测试设计、重构和卡住时的处理原则。

**适用场景：**
- 新功能开发。
- 修复 bug。
- 行为变更或重构。

### `systematic-debugging`

**作用：**
处理任何 bug、测试失败或异常行为时，先找 root cause，再谈修复。

**核心功能：**
- 强制执行根因调查流程。
- 先复现、读错误、看最近改动、收集证据。
- 在多组件系统中强调加诊断信息和边界观察。
- 用假设与验证替代拍脑袋式修复。

**适用场景：**
- 任意技术问题。
- 已经试过几个 fix 但没解决。
- 压力大、容易走捷径时。

### `verification-before-completion`

**作用：**
在宣称“完成了”“修好了”“通过了”之前，必须先跑最新验证并确认结果。

**核心功能：**
- 定义 “Evidence before claims”。
- 要求先识别验证命令，再执行、阅读输出、确认结论。
- 覆盖测试、构建、lint、bug 修复、agent 完成等多种声明。
- 防止靠猜测或旧结果宣称成功。

**适用场景：**
- 准备说“done”之前。
- 提交、push、开 PR 之前。
- 任何要对状态做正向判断的时候。

### `requesting-code-review`

**作用：**
在任务完成、重大功能落地或合并前，主动请求代码审查。

**核心功能：**
- 定义何时必须做 review、何时建议做 review。
- 说明如何准备 reviewer 所需的上下文和 git SHAs。
- 把审查结果按严重级别转成后续动作。
- 与 `subagent-driven-development` 的任务后审查流程衔接。

**适用场景：**
- 每个关键任务完成后。
- 大功能完成后。
- 合并前做最终检查。

### `receiving-code-review`

**作用：**
在收到 code review 反馈时，先技术性评估，再决定是否实现，不做表演式赞同。

**核心功能：**
- 规定处理 review 的响应模式：读懂、验证、评估、回应、再实现。
- 强调对不清晰或可疑反馈先求证。
- 区分对人类搭档和外部 reviewer 的处理方式。
- 允许基于技术理由进行 push back。

**适用场景：**
- 收到 reviewer 评论后。
- 对某条建议不确定是否适用于当前代码库时。
- 需要避免机械照单全收时。

### `writing-skills`

**作用：**
用于创建、编辑和验证新的 skill，把 skill 写作本身当作一种 TDD。

**核心功能：**
- 说明什么样的内容值得抽象成 skill。
- 定义 skill 的结构、命名、frontmatter 和组织方式。
- 用 RED-GREEN-REFACTOR 来验证 skill 是否真的能改变 agent 行为。
- 强调为 skill 设计触发条件、反例、漏洞封堵和 rationalization 防护。

**适用场景：**
- 新增一个可复用流程或方法时。
- 修补现有 skill 的漏洞时。
- 想把个人经验沉淀成可发现、可复用的能力时。

## 一页速查

| Skill | 主要用途 | 典型时机 |
|---|---|---|
| `using-superpowers` | 决定何时、如何使用其他 skill | 任何对话开始 |
| `brainstorming` | 先做设计，不直接实现 | 新功能/改行为前 |
| `writing-plans` | 把设计写成实施计划 | spec 批准后 |
| `using-git-worktrees` | 建隔离工作区 | 开发开始前 |
| `subagent-driven-development` | 在当前会话里按任务并行执行计划 | 有 subagent 且任务独立 |
| `executing-plans` | 顺序执行实施计划 | 无 subagent 或独立会话 |
| `finishing-a-development-branch` | 收尾、合并、PR、清理 | 测试通过后 |
| `dispatching-parallel-agents` | 并行处理独立问题 | 多个独立故障/任务 |
| `test-driven-development` | 先测后写 | 实现新功能或 bugfix |
| `systematic-debugging` | 先查根因再修 | 遇到 bug 或失败 |
| `verification-before-completion` | 先验证再宣称完成 | 准备说 done 前 |
| `requesting-code-review` | 主动发起审查 | 任务结束或合并前 |
| `receiving-code-review` | 技术性处理审查反馈 | 收到 review 后 |
| `writing-skills` | 创建或维护 skill | 改 skill 或写新 skill 时 |

## 建议阅读顺序

如果你第一次看这个仓库，建议按下面顺序读：

1. `skills/using-superpowers/SKILL.md`
2. `skills/brainstorming/SKILL.md`
3. `skills/writing-plans/SKILL.md`
4. `skills/using-git-worktrees/SKILL.md`
5. `skills/subagent-driven-development/SKILL.md`
6. `skills/finishing-a-development-branch/SKILL.md`
7. 再读质量保障类 skill：
   - `skills/test-driven-development/SKILL.md`
   - `skills/systematic-debugging/SKILL.md`
   - `skills/verification-before-completion/SKILL.md`
   - `skills/requesting-code-review/SKILL.md`
   - `skills/receiving-code-review/SKILL.md`

## 备注

- 本文档是总览，不替代各个 `SKILL.md` 的完整规则。
- 如果要真正执行某个流程，应直接读对应 skill 的原文。
- `skills/brainstorming/` 等目录下可能还包含支持文档、prompt 模板或脚本；这些通常是该 skill 的辅助材料，不是单独的一级 skill。
