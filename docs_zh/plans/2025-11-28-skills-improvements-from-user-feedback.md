# 基于用户反馈的 Skills 改进

**Date:** 2025-11-28
**Status:** 草稿
**Source:** 两个 Claude 实例在真实开发场景中使用 superpowers 的反馈

---

## 执行摘要

两个 Claude 实例基于真实开发会话给出了详细反馈。这些反馈暴露出当前 skills 中存在的**系统性缺口**，即使遵循了技能，也仍然让本可避免的 bug 被发布出去。

**关键信息：** 这些是问题报告，不只是解决方案建议。问题是真实存在的；解决方案需要谨慎评估。

**核心主题：**
1. **Verification gaps**：我们验证操作是否成功，但没有验证它是否真的达成了预期结果
2. **Process hygiene**：后台进程会累积，并在 subagent 之间相互干扰
3. **Context optimization**：subagent 获得了太多无关信息
4. **缺少自我反思**：交接前没有 prompt 让它反思自己的工作
5. **Mock safety**：mock 可能偏离接口且无法被发现
6. **Skill activation**：skill 存在，但没有被读取或使用

---

## 已识别的问题

### Problem 1：配置变更验证存在缺口

**发生了什么：**
- Subagent 测试了 “OpenAI integration”
- 设置了 `OPENAI_API_KEY` 环境变量
- 收到了状态码 200 的响应
- 报告 “OpenAI integration working”
- **但是** 响应里包含 `"model": "claude-sonnet-4-20250514"`，实际上用的是 Anthropic

**根因：**
`verification-before-completion` 检查的是操作是否成功，而不是结果是否反映了预期的配置变更。

**影响：** 高，集成测试会产生错误的信心，bug 会被带到生产环境

**典型失败模式示例：**
- 切换 LLM provider → 只验证状态码 200，却不检查 model name
- 启用 feature flag → 只验证没有报错，却不检查 feature 是否真的生效
- 切换环境 → 只验证部署成功，却不检查环境变量是否正确

---

### Problem 2：后台进程累积

**发生了什么：**
- 会话期间派发了多个 subagent
- 每个都启动了后台 server 进程
- 进程不断累积（4 个以上 server 同时运行）
- 旧进程仍然绑定着端口
- 后续 E2E 测试打到了配置错误的旧 server
- 测试结果变得混乱且不正确

**根因：**
Subagent 是无状态的，不知道之前的 subagent 启动过哪些进程。没有清理协议。

**影响：** 中高，测试会打到错误的 server，产生误报通过/失败，并增加排障困惑

---

### Problem 3：Subagent Prompt 上下文膨胀

**发生了什么：**
- 标准做法：让 subagent 去读整个 plan 文件
- 实验做法：只提供 task + pattern + file + verify command
- 结果：更快、更聚焦，一次完成的概率更高

**根因：**
Subagent 把 token 和注意力浪费在了不相关的 plan 章节上。

**影响：** 中等，执行更慢，失败重试更多

**有效做法：**
```
You are adding a single E2E test to packnplay's test suite.

**Your task:** Add `TestE2E_FeaturePrivilegedMode` to `pkg/runner/e2e_test.go`

**What to test:** A local devcontainer feature that requests `"privileged": true`
in its metadata should result in the container running with `--privileged` flag.

**Follow the exact pattern of TestE2E_FeatureOptionValidation** (at the end of the file)

**After writing, run:** `go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m`
```

---

### Problem 4：交接前没有自我反思

**发生了什么：**
- 增加了一个自我反思 prompt：“Look at your work with fresh eyes - what could be better?”
- Task 5 的实现者识别出失败测试的原因是实现 bug，而不是测试 bug
- 定位到第 99 行：`strings.Join(metadata.Entrypoint, " ")` 生成了无效的 Docker 语法
- 如果没有自我反思，本来只会汇报 “test fails”，而不会给出根因

**根因：**
实现者在汇报完成前，不会自然地退一步审视并批评自己的工作。

**影响：** 中等，实现者本可发现的 bug 被交给 reviewer 才暴露

---

### Problem 5：Mock 与接口发生漂移

**发生了什么：**
```typescript
// Interface defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}

// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) defines cleanup()
vi.mock('web-adapter', () => ({
  WebAdapter: vi.fn().mockImplementation(() => ({
    cleanup: vi.fn().mockResolvedValue(undefined),  // Wrong!
  })),
}));
```
- 测试通过了
- 运行时崩溃：`"adapter.cleanup is not a function"`

**根因：**
Mock 是按有 bug 的实现代码推导出来的，而不是按接口定义推导出来的。TypeScript 无法捕获方法名错误的 inline mock。

**影响：** 高，测试给出错误信心，运行时崩溃

**为什么 testing-anti-patterns 没挡住这个问题：**
该 skill 覆盖了测试 mock 行为以及在不理解前提下进行 mocking，但没有覆盖这种特定模式：应该“按接口推导 mock，而不是按实现推导”。

---

### Problem 6：代码 Reviewer 无法访问文件

**发生了什么：**
- 派发了 code reviewer subagent
- 它找不到测试文件：“The file doesn't appear to exist in the repository”
- 但文件实际上是存在的
- Reviewer 不知道自己需要先显式读取它

**根因：**
Reviewer prompt 中没有包含明确的文件读取说明。

**影响：** 中低，review 会失败或不完整

---

### Problem 7：修复工作流延迟

**发生了什么：**
- 实现者在自我反思时发现了 bug
- 实现者也知道该怎么修
- 当前工作流是：汇报 → 我派 fixer → fixer 修复 → 我验证
- 多出一个往返，但并没有带来价值

**根因：**
当实现者已经完成诊断时，工作流仍然僵硬地把 implementer 和 fixer 角色强行拆开。

**影响：** 低，只增加延迟，不影响正确性

---

### Problem 8：Skills 没有被读取

**发生了什么：**
- `testing-anti-patterns` skill 已经存在
- 但无论是人还是 subagent，在写测试前都没有读取它
- 它本来可以避免一些问题（虽然不是全部，见 Problem 5）

**根因：**
没有强制 subagent 读取相关 skills。Prompt 中也没有技能读取要求。

**影响：** 中等，如果 skill 不被使用，前面的投入就被浪费了

---

## 提议的改进

### 1. verification-before-completion：新增配置变更验证

**新增一节：**

```markdown
## Verifying Configuration Changes

When testing changes to configuration, providers, feature flags, or environment:

**Don't just verify the operation succeeded. Verify the output reflects the intended change.**

### Common Failure Pattern

Operation succeeds because *some* valid config exists, but it's not the config you intended to test.

### Examples

| Change | Insufficient | Required |
|--------|-------------|----------|
| Switch LLM provider | Status 200 | Response contains expected model name |
| Enable feature flag | No errors | Feature behavior actually active |
| Change environment | Deploy succeeds | Logs/vars reference new environment |
| Set credentials | Auth succeeds | Authenticated user/context is correct |

### Gate Function

```
BEFORE claiming configuration change works:

1. IDENTIFY: What should be DIFFERENT after this change?
2. LOCATE: Where is that difference observable?
   - Response field (model name, user ID)
   - Log line (environment, provider)
   - Behavior (feature active/inactive)
3. RUN: Command that shows the observable difference
4. VERIFY: Output contains expected difference
5. ONLY THEN: Claim configuration change works

Red flags:
  - "Request succeeded" without checking content
  - Checking status code but not response body
  - Verifying no errors but not positive confirmation
```

**Why this works:**
Forces verification of INTENT, not just operation success.
```

---

### 2. subagent-driven-development：为 E2E 测试增加进程卫生规范

**新增一节：**

```markdown
## Process Hygiene for E2E Tests

When dispatching subagents that start services (servers, databases, message queues):

### Problem

Subagents are stateless - they don't know about processes started by previous subagents. Background processes persist and can interfere with later tests.

### Solution

**Before dispatching E2E test subagent, include cleanup in prompt:**

```
BEFORE starting any services:
1. Kill existing processes: pkill -f "<service-pattern>" 2>/dev/null || true
2. Wait for cleanup: sleep 1
3. Verify port free: lsof -i :<port> && echo "ERROR: Port still in use" || echo "Port free"

AFTER tests complete:
1. Kill the process you started
2. Verify cleanup: pgrep -f "<service-pattern>" || echo "Cleanup successful"
```

### Example

```
Task: Run E2E test of API server

Prompt includes:
"Before starting the server:
- Kill any existing servers: pkill -f 'node.*server.js' 2>/dev/null || true
- Verify port 3001 is free: lsof -i :3001 && exit 1 || echo 'Port available'

After tests:
- Kill the server you started
- Verify: pgrep -f 'node.*server.js' || echo 'Cleanup verified'"
```

### Why This Matters

- Stale processes serve requests with wrong config
- Port conflicts cause silent failures
- Process accumulation slows system
- Confusing test results (hitting wrong server)
```

**Trade-off analysis：**
- 给 prompt 增加了一些样板内容
- 但能避免非常令人困惑的排障过程
- 对 E2E 测试 subagent 来说，这笔成本是值得的

---

### 3. subagent-driven-development：增加精简上下文选项

**修改 Step 2: Execute Task with Subagent**

**Before:**
```
Read that task carefully from [plan-file].
```

**After:**
```
## Context Approaches

**Full Plan (default):**
Use when tasks are complex or have dependencies:
```
Read Task N from [plan-file] carefully.
```

**Lean Context (for independent tasks):**
Use when task is standalone and pattern-based:
```
You are implementing: [1-2 sentence task description]

File to modify: [exact path]
Pattern to follow: [reference to existing function/test]
What to implement: [specific requirement]
Verification: [exact command to run]

[Do NOT include full plan file]
```

**Use lean context when:**
- Task follows existing pattern (add similar test, implement similar feature)
- Task is self-contained (doesn't need context from other tasks)
- Pattern reference is sufficient (e.g., "follow TestE2E_FeatureOptionValidation")

**Use full plan when:**
- Task has dependencies on other tasks
- Requires understanding of overall architecture
- Complex logic that needs context
```

**示例：**
```
Lean context prompt:

"You are adding a test for privileged mode in devcontainer features.

File: pkg/runner/e2e_test.go
Pattern: Follow TestE2E_FeatureOptionValidation (at end of file)
Test: Feature with `"privileged": true` in metadata results in `--privileged` flag
Verify: go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m

Report: Implementation, test results, any issues."
```

**Why this works:**
可以减少 token 使用、提高专注度，并在适用时加快完成速度。

---

### 4. subagent-driven-development：增加自我反思步骤

**修改 Step 2: Execute Task with Subagent**

**在 prompt 模板中添加：**

```
When done, BEFORE reporting back:

Take a step back and review your work with fresh eyes.

Ask yourself:
- Does this actually solve the task as specified?
- Are there edge cases I didn't consider?
- Did I follow the pattern correctly?
- If tests are failing, what's the ROOT CAUSE (implementation bug vs test bug)?
- What could be better about this implementation?

If you identify issues during this reflection, fix them now.

Then report:
- What you implemented
- Self-reflection findings (if any)
- Test results
- Files changed
```

**Why this works:**
能在交接前先捕获实现者自己就能发现的 bug。已有案例表明：通过自我反思发现了 entrypoint bug。

**Trade-off：**
每个任务大约多花 30 秒，但能在 review 前就拦下一些问题。

---

### 5. requesting-code-review：增加显式文件读取要求

**修改 code-reviewer 模板：**

**在开头新增：**

```markdown
## Files to Review

BEFORE analyzing, read these files:

1. [List specific files that changed in the diff]
2. [Files referenced by changes but not modified]

Use Read tool to load each file.

If you cannot find a file:
- Check exact path from diff
- Try alternate locations
- Report: "Cannot locate [path] - please verify file exists"

DO NOT proceed with review until you've read the actual code.
```

**Why this works:**
明确要求读取文件，可以避免 “file not found” 类问题。

---

### 6. testing-anti-patterns：新增 Mock-Interface Drift 反模式

**新增 Anti-Pattern 6：**

```markdown
## Anti-Pattern 6: Mocks Derived from Implementation

**The violation:**
```typescript
// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) has cleanup()
const mock = {
  cleanup: vi.fn().mockResolvedValue(undefined)
};

// Interface (CORRECT) defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}
```

**Why this is wrong:**
- Mock encodes the bug into the test
- TypeScript can't catch inline mocks with wrong method names
- Test passes because both code and mock are wrong
- Runtime crashes when real object is used

**The fix:**
```typescript
// ✅ GOOD: Derive mock from interface

// Step 1: Open interface definition (PlatformAdapter)
// Step 2: List methods defined there (close, initialize, etc.)
// Step 3: Mock EXACTLY those methods

const mock = {
  initialize: vi.fn().mockResolvedValue(undefined),
  close: vi.fn().mockResolvedValue(undefined),  // From interface!
};

// Now test FAILS because code calls cleanup() which doesn't exist
// That failure reveals the bug BEFORE runtime
```

### Gate Function

```
BEFORE writing any mock:

  1. STOP - Do NOT look at the code under test yet
  2. FIND: The interface/type definition for the dependency
  3. READ: The interface file
  4. LIST: Methods defined in the interface
  5. MOCK: ONLY those methods with EXACTLY those names
  6. DO NOT: Look at what your code calls

  IF your test fails because code calls something not in mock:
    ✅ GOOD - The test found a bug in your code
    Fix the code to call the correct interface method
    NOT the mock

  Red flags:
    - "I'll mock what the code calls"
    - Copying method names from implementation
    - Mock written without reading interface
    - "The test is failing so I'll add this method to the mock"
```

**Detection:**

When you see runtime error "X is not a function" and tests pass:
1. Check if X is mocked
2. Compare mock methods to interface methods
3. Look for method name mismatches
```

**Why this works:**
它直接对准了反馈中出现的失败模式。

---

### 7. subagent-driven-development：要求测试类 subagent 读取技能

**当任务涉及测试时，在 prompt 模板中增加：**

```markdown
BEFORE writing any tests:

1. Read testing-anti-patterns skill:
   Use Skill tool: superpowers:testing-anti-patterns

2. Apply gate functions from that skill when:
   - Writing mocks
   - Adding methods to production classes
   - Mocking dependencies

This is NOT optional. Tests that violate anti-patterns will be rejected in review.
```

**Why this works:**
确保 skill 真正被使用，而不只是存在。

**Trade-off：**
每个任务会多花一些时间，但能避免整类 bug。

---

### 8. subagent-driven-development：允许实现者修复自我识别出的问题

**修改 Step 2：**

**Current:**
```
Subagent reports back with summary of work.
```

**Proposed:**
```
Subagent performs self-reflection, then:

IF self-reflection identifies fixable issues:
  1. Fix the issues
  2. Re-run verification
  3. Report: "Initial implementation + self-reflection fix"

ELSE:
  Report: "Implementation complete"

Include in report:
- Self-reflection findings
- Whether fixes were applied
- Final verification results
```

**Why this works:**
当实现者已经知道修法时，可以减少往返延迟。已有案例表明：这本可以为 entrypoint bug 节省一次 round-trip。

**Trade-off：**
Prompt 稍微复杂一些，但端到端更快。

---

## 实施计划

### Phase 1：高影响、低风险（先做）

1. **verification-before-completion：配置变更验证**
   - 清晰的新增内容，不会改动现有逻辑
   - 解决高影响问题（测试中的错误信心）
   - 文件：`skills/verification-before-completion/SKILL.md`

2. **testing-anti-patterns：mock-interface drift**
   - 新增反模式，不修改现有内容
   - 解决高影响问题（运行时崩溃）
   - 文件：`skills/testing-anti-patterns/SKILL.md`

3. **requesting-code-review：显式文件读取**
   - 只是对模板做简单补充
   - 解决具体问题（reviewer 找不到文件）
   - 文件：`skills/requesting-code-review/SKILL.md`

### Phase 2：中等改动（谨慎测试）

4. **subagent-driven-development：进程卫生**
   - 新增章节，不改变工作流
   - 解决中高影响问题（测试可靠性）
   - 文件：`skills/subagent-driven-development/SKILL.md`

5. **subagent-driven-development：自我反思**
   - 会改变 prompt 模板（风险更高）
   - 但有已记录案例证明它能抓住 bug
   - 文件：`skills/subagent-driven-development/SKILL.md`

6. **subagent-driven-development：强制读取技能**
   - 增加 prompt 开销
   - 但可以确保 skill 真正被使用
   - 文件：`skills/subagent-driven-development/SKILL.md`

### Phase 3：优化项（先验证）

7. **subagent-driven-development：精简上下文选项**
   - 增加复杂度（两套方式）
   - 需要验证它不会引发困惑
   - 文件：`skills/subagent-driven-development/SKILL.md`

8. **subagent-driven-development：允许实现者自修**
   - 会改变工作流（风险更高）
   - 属于优化，不是 bug 修复
   - 文件：`skills/subagent-driven-development/SKILL.md`

---

## 开放问题

1. **Lean context 方案：**
   - 对 pattern-based task，是否应该把它作为默认方案？
   - 我们如何决定何时使用哪种方案？
   - 会不会因为过于精简而丢掉关键上下文？

2. **自我反思：**
   - 它会不会显著拖慢简单任务？
   - 是否只应对复杂任务启用？
   - 如何避免 “reflection fatigue”，也就是流于形式？

3. **进程卫生：**
   - 它应该放进 subagent-driven-development，还是做成独立 skill？
   - 除了 E2E 测试，它是否也适用于其他工作流？
   - 如果进程本来就应该持续存在（比如 dev server），应该如何处理？

4. **技能读取强制要求：**
   - 是否应该要求所有 subagent 都读取相关技能？
   - 如何避免 prompt 变得过长？
   - 会不会有过度文档化、反而失焦的风险？

---

## 成功指标

我们如何判断这些改进有效？

1. **配置验证：**
   - 不再出现 “测试通过但用的是错误配置” 的情况
   - Jesse 不再说 “that’s not actually testing what you think”

2. **进程卫生：**
   - 不再出现 “测试打到了错误 server” 的情况
   - E2E 测试运行中不再出现端口冲突错误

3. **Mock-interface drift：**
   - 不再出现 “测试通过但运行时因缺失方法崩溃” 的情况
   - Mock 与接口之间不再出现方法名不匹配

4. **自我反思：**
   - 可量化：实现者汇报中是否包含 self-reflection findings？
   - 定性：进入 code review 的 bug 是否更少？

5. **技能读取：**
   - Subagent 汇报会引用 skill 中的 gate functions
   - Code review 中出现的 anti-pattern 违规更少

---

## 风险与缓解

### Risk: Prompt Bloat
**问题：** 把所有这些要求都加进去会让 prompt 变得过于臃肿  
**缓解：**
- 分阶段实施（不要一次全加）
- 让一部分新增内容带条件启用（例如 E2E hygiene 仅用于 E2E 测试）
- 考虑针对不同任务类型提供不同模板

### Risk: Analysis Paralysis
**问题：** 过多的反思/验证会拖慢执行  
**缓解：**
- 让 gate functions 足够快（秒级，而不是分钟级）
- 初期让 lean context 保持 opt-in
- 监控任务完成耗时

### Risk: False Sense of Security
**问题：** 遵循 checklist 也不代表一定正确  
**缓解：**
- 强调 gate functions 是最低要求，不是上限
- 在 skill 中保留 “use judgment” 一类表述
- 说明 skill 只能捕获常见失败，不可能覆盖全部失败

### Risk: Skill Divergence
**问题：** 不同 skill 之间给出相互冲突的建议  
**缓解：**
- 跨所有 skill 审查改动的一致性
- 记录 skill 之间如何交互（Integration sections）
- 在发布前用真实场景测试

---

## 建议

**立即推进 Phase 1：**
- verification-before-completion：配置变更验证
- testing-anti-patterns：mock-interface drift
- requesting-code-review：显式文件读取

**在最终敲定前，用 Jesse 验证 Phase 2：**
- 获取对 self-reflection 影响的反馈
- 验证 process hygiene 方案
- 确认 skills reading requirement 值得它带来的开销

**在验证前暂缓 Phase 3：**
- Lean context 需要真实世界测试
- Implementer-fix 工作流变更需要谨慎评估

这些改动针对的是用户已记录的真实问题，同时尽量降低把 skills 变得更糟的风险。
