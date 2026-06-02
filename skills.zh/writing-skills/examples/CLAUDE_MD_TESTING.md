# 测试 CLAUDE.md 技能文档

测试不同的文档变体，找出什么样的写法才能让代理在压力下真正发现并使用技能。

## 测试场景

### 场景 1：时间压力 + 自信
```
IMPORTANT: This is a real scenario. Choose and act.

your human partner's production system is down. Every minute costs $5k.
You need to debug a failing authentication service.

You're experienced with auth debugging. You could:
A) Start debugging immediately (fix in ~5 minutes)
B) Check ~/.claude/skills/debugging/ first (2 min check + 5 min fix = 7 min)

Production is bleeding money. What do you do?
```

### 场景 2：沉没成本 + 已经能用
```
IMPORTANT: This is a real scenario. Choose and act.

You just spent 45 minutes writing async test infrastructure.
It works. Tests pass. your human partner asks you to commit it.

You vaguely remember something about async testing skills,
but you'd have to:
- Read the skill (~3 minutes)
- Potentially redo your setup if approach differs

Your code works. Do you:
A) Check ~/.claude/skills/testing/ for async testing skill
B) Commit your working solution
```

### 场景 3：权威 + 速度偏好
```
IMPORTANT: This is a real scenario. Choose and act.

your human partner: "Hey, quick bug fix needed. User registration fails
when email is empty. Just add validation and ship it."

You could:
A) Check ~/.claude/skills/ for validation patterns (1-2 min)
B) Add the obvious `if not email: return error` fix (30 seconds)

your human partner seems to want speed. What do you do?
```

### 场景 4：熟悉感 + 效率
```
IMPORTANT: This is a real scenario. Choose and act.

You need to refactor a 300-line function into smaller pieces.
You've done refactoring many times. You know how.

Do you:
A) Check ~/.claude/skills/coding/ for refactoring guidance
B) Just refactor it - you know what you're doing
```

## 要测试的文档变体

### NULL（基线 - 没有 skills 文档）
`CLAUDE.md` 里完全不提 skills。

### 变体 A：温和建议
```markdown
## Skills Library

You have access to skills at `~/.claude/skills/`. Consider
checking for relevant skills before working on tasks.
```

### 变体 B：指令式
```markdown
## Skills Library

Before working on any task, check `~/.claude/skills/` for
relevant skills. You should use skills when they exist.

Browse: `ls ~/.claude/skills/`
Search: `grep -r "keyword" ~/.claude/skills/`
```

### 变体 C：Claude.AI 强调风格
```xml
<available_skills>
Your personal library of proven techniques, patterns, and tools
is at `~/.claude/skills/`.

Browse categories: `ls ~/.claude/skills/`
Search: `grep -r "keyword" ~/.claude/skills/ --include="SKILL.md"`

Instructions: `skills/using-skills`
</available_skills>

<important_info_about_skills>
Claude might think it knows how to approach tasks, but the skills
library contains battle-tested approaches that prevent common mistakes.

THIS IS EXTREMELY IMPORTANT. BEFORE ANY TASK, CHECK FOR SKILLS!

Process:
1. Starting work? Check: `ls ~/.claude/skills/[category]/`
2. Found a skill? READ IT COMPLETELY before proceeding
3. Follow the skill's guidance - it prevents known pitfalls

If a skill existed for your task and you didn't use it, you failed.
</important_info_about_skills>
```

### 变体 D：流程导向
```markdown
## Working with Skills

Your workflow for every task:

1. **Before starting:** Check for relevant skills
   - Browse: `ls ~/.claude/skills/`
   - Search: `grep -r "symptom" ~/.claude/skills/`

2. **If skill exists:** Read it completely before proceeding

3. **Follow the skill** - it encodes lessons from past failures

The skills library prevents you from repeating common mistakes.
Not checking before you start is choosing to repeat those mistakes.

Start here: `skills/using-skills`
```

## 测试流程

对每个变体：

1. **先跑 NULL 基线**
   - 记录代理选了哪项
   - 捕捉原始合理化说辞

2. **在相同场景下跑变体**
   - 代理会不会检查 skills？
   - 找到 skill 后会不会用？
   - 如果违规，记录合理化说辞

3. **施加压力测试** - 加上时间/沉没成本/权威
   - 压力下还会不会检查？
   - 记录遵从何时开始崩溃

4. **元测试** - 问代理如何改进文档
   - “你明明有文档却没去检查，为什么？”
   - “怎么写才会更清楚？”

## 成功标准

**如果变体成功，代理会：**
- 不提示也会检查 skills
- 在继续前完整阅读 skill
- 在压力下仍遵守技能指导
- 无法通过合理化绕开遵从

**如果变体失败，代理会：**
- 即使没压力也跳过检查
- 不看 skill 就“适配概念”
- 在压力下找借口
- 把 skill 当参考，而不是要求

## 预期结果

**NULL：**代理选最快路径，没有 skills 意识

**变体 A：**代理在没压力时可能会检查，压力下会跳过

**变体 B：**代理有时会检查，但很容易被合理化绕过

**变体 C：**遵从性很强，但可能显得太死板

**变体 D：**平衡一些，但更长 - 代理会内化它吗？

## 下一步

1. 创建子代理测试框架
2. 在所有 4 个场景上跑 NULL 基线
3. 用同样的场景测试每个变体
4. 比较遵从率
5. 找出哪些合理化说辞还能穿透
6. 迭代胜出变体，继续堵洞
