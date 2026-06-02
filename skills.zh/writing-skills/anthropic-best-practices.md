# 技能编写最佳实践

> 学习如何编写更有效的 Skill，让 Claude 能发现、读懂并真正使用它。

好的 Skill 应该简洁、结构清晰，并且经过真实使用验证。本指南给出的是实操层面的编写决策，帮助你写出 Claude 能有效发现并执行的 Skill。

关于 Skills 的概念背景，请参见 [Skills overview](/en/docs/agents-and-tools/agent-skills/overview)。

## 核心原则

### 简洁最重要

[上下文窗口](https://platform.claude.com/docs/en/build-with-claude/context-windows) 是公共资源。你的 Skill 会与系统提示、对话历史、其他 Skill 的元数据以及当前请求共享上下文。

不是每个 token 都会立刻产生成本：启动时，只有所有 Skills 的元数据（`name` 和 `description`）会预加载。Claude 只有在某个 Skill 变得相关时才读取 `SKILL.md`，而且只在需要时再读取额外文件。但 `SKILL.md` 仍然要尽量简洁，因为一旦被加载，每个 token 都会和对话历史及其他上下文竞争。

**默认假设：Claude 已经很聪明**

只补充 Claude 不一定知道的信息。每一条信息都要问：

- “Claude 真的需要这段解释吗？”
- “我能否假设它已经知道？”
- “这段话值不值得这些 token？”

**好例子：简洁**（约 50 tokens）：

````markdown
## 提取 PDF 文本

使用 `pdfplumber` 提取文本：

```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
````

**坏例子：太啰嗦**（约 150 tokens）：

```markdown
## 提取 PDF 文本

PDF（Portable Document Format）是一种常见文件格式，包含文本、图片和其他内容。要从 PDF 中提取文本，你需要使用一个库……
```

简洁版本默认 Claude 已经知道 PDF 和库是怎么回事。

### 设定合适的自由度

根据任务的脆弱程度和变动空间，匹配指令的具体程度。

**高自由度**（文本说明）：

适用场景：

- 多种做法都可接受
- 决策依赖上下文
- 由经验规则来引导

示例：

```markdown
## 代码审查流程

1. 分析代码结构和组织方式
2. 检查潜在 bug 和边界情况
3. 提出可读性和可维护性改进建议
4. 验证是否符合项目约定
```

**中等自由度**（带参数的伪代码或脚本）：

适用场景：

- 有偏好的模式
- 允许一定变化
- 配置会影响行为

示例：

````markdown
## 生成报告

使用这个模板，并按需调整：

```python
def generate_report(data, format="markdown", include_charts=True):
    # 处理数据
    # 按指定格式生成输出
    # 可选地加入图表
```
````

**低自由度**（特定脚本、很少或没有参数）：

适用场景：

- 操作脆弱且容易出错
- 一致性很关键
- 必须遵循特定顺序

示例：

````markdown
## 数据库迁移

严格运行这个脚本：

```bash
python scripts/migrate.py --verify --backup
```

不要改命令，也不要额外加参数。
````

可以把 Claude 想成走路径的机器人：

- **两侧都是悬崖的窄桥**：只有一条安全路线，给出明确护栏和精确指令（低自由度）
- **没有危险的开阔地**：很多路都能成功，给出大方向并相信 Claude 自己判断（高自由度）

### 测试你计划使用的所有模型

Skills 是加在模型之上的能力，所以效果取决于底层模型。要在你计划使用的所有模型上测试 Skill。

**测试时要考虑的模型差异：**

- **Claude Haiku**（快、经济）：Skill 是否足够清晰？
- **Claude Sonnet**（均衡）：Skill 是否高效且明确？
- **Claude Opus**（推理更强）：Skill 是否没有过度解释？

对 Opus 很合适的内容，可能对 Haiku 来说还不够。若要跨多个模型使用，尽量写出能同时适配它们的说明。

## Skill 结构

<Note>
  **YAML Frontmatter**：`SKILL.md` 的 frontmatter 需要两个字段：

  * `name` - Skill 的人类可读名称（最多 64 个字符）
  * `description` - 一行说明 Skill 做什么，以及何时使用（最多 1024 个字符）

  完整结构请参见 [Skills overview](/en/docs/agents-and-tools/agent-skills/overview#skill-structure)。
</Note>

### 命名约定

使用一致的命名模式，让 Skills 更容易被引用和讨论。我们推荐使用**动名词形式**（动词 + -ing），因为它能清楚描述 Skill 提供的活动或能力。

**好的命名示例（动名词形式）**：

* "Processing PDFs"
* "Analyzing spreadsheets"
* "Managing databases"
* "Testing code"
* "Writing documentation"

**可接受的替代形式**：

* 名词短语：`PDF Processing`、`Spreadsheet Analysis`
* 动作导向：`Process PDFs`、`Analyze Spreadsheets`

**避免：**

* 模糊名称：`Helper`、`Utils`、`Tools`
* 过于泛化：`Documents`、`Data`、`Files`
* 在同一技能集合里命名风格不一致

一致的命名有助于：

* 在文档和对话中引用 Skills
* 一眼看出 Skill 的用途
* 管理和搜索多个 Skills
* 维护一个专业、统一的技能库

### 编写有效的描述

`description` 字段用于发现 Skill，应该同时包含“做什么”和“何时使用”。

<Warning>
  **始终使用第三人称**。description 会被注入系统提示词，视角不一致会导致发现问题。

  * **好**：`Processes Excel files and generates reports`
  * **避免**：`I can help you process Excel files`
  * **避免**：`You can use this to process Excel files`
</Warning>

**要具体，并包含关键术语**。既要写 Skill 的用途，也要写使用时的触发上下文。

每个 Skill 只有一个 description。它对技能选择至关重要：Claude 会用它从可能 100+ 个 Skills 中选出正确的那个。description 必须足够明确，让 Claude 知道什么时候选择它，而 `SKILL.md` 的其余部分再提供实现细节。

有效示例：

**PDF 处理 Skill：**

```yaml
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
```

**Excel 分析 Skill：**

```yaml
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.
```

**Git Commit Helper Skill：**

```yaml
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.
```

避免这种模糊描述：

```yaml
description: Helps with documents
```

```yaml
description: Processes data
```

```yaml
description: Does stuff with files
```

### 渐进式披露模式

`SKILL.md` 应该像目录页一样，把 Claude 引到需要的细节文件上。关于渐进式披露如何工作，请参见概览中的 [How Skills work](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)。

**实用建议：**

* 保持 `SKILL.md` 主体在 500 行以内
* 当接近这个上限时，把内容拆到单独文件
* 用下面这些模式来组织指令、代码和资源

#### 从简单到复杂的视觉概览

一个基础 Skill 只需要一个包含元数据和指令的 `SKILL.md`。

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=87782ff239b297d9a9e8e1b72ed72db9" alt="简单的 SKILL.md 文件，显示 YAML frontmatter 和 markdown 正文" data-og-width="2048" width="2048" data-og-height="1153" height="1153" data-path="images/agent-skills-simple-file.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=c61cc33b6f5855809907f7fda94cd80e 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=90d2c0c1c76b36e8d485f49e0810dbfd 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=ad17d231ac7b0bea7e5b4d58fb4aeabb 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f5d0a7a3c668435bb0aee9a3a8f8c329 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0e927c1af9de5799cfe557d12249f6e6 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=46bbb1a51dd4c8202a470ac8c80a893d 2500w" />

随着 Skill 变大，你可以附加额外内容，Claude 只会在需要时加载：

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=a5e0aa41e3d53985a7e3e43668a33ea3" alt="把 reference.md 和 forms.md 之类的额外参考文件打包进去" data-og-width="2048" width="2048" data-og-height="1327" height="1327" data-path="images/agent-skills-bundling-content.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f8a0e73783e99b4a643d79eac86b70a2 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=dc510a2a9d3f14359416b706f067904a 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=82cd6286c966303f7dd914c28170e385 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=56f3be36c77e4fe4b523df209a6824c6 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=d22b5161b2075656417d56f41a74f3dd 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=3dd4bdd6850ffcc96c6c45fcb0acd6eb 2500w" />

完整的 Skill 目录可能长这样：

```text
pdf/
├── SKILL.md              # 主指令（触发后加载）
├── FORMS.md              # 表单填写指南（按需加载）
├── reference.md          # API 参考（按需加载）
├── examples.md           # 使用示例（按需加载）
└── scripts/
    ├── analyze_form.py   # 工具脚本（执行，不加载）
    ├── fill_form.py      # 填表脚本
    └── validate.py       # 校验脚本
```

#### 模式 1：带参考文件的高层指南

````markdown
---
name: PDF Processing
description: Extracts text and tables from PDF files, fills forms, and merges documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
---

# PDF Processing

## Quick start

用 pdfplumber 提取文本：
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

## Advanced features

**Form filling**：看 [FORMS.md](FORMS.md) 的完整指南  
**API reference**：看 [REFERENCE.md](REFERENCE.md) 的完整方法  
**Examples**：看 [EXAMPLES.md](EXAMPLES.md) 的常见模式
````

Claude 只有在需要时才会加载 `FORMS.md`、`REFERENCE.md` 或 `EXAMPLES.md`。

#### 模式 2：按领域组织

当 Skill 涉及多个领域时，按领域组织内容，避免加载无关上下文。比如用户问销售指标时，Claude 只需要销售相关 schema，而不需要财务或市场数据。这样 token 更少，关注点更集中。

```text
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

```markdown
# BigQuery Data Analysis

## Available datasets

**Finance**：收入、ARR、计费 → 看 [reference/finance.md](reference/finance.md)  
**Sales**：机会、管道、账户 → 看 [reference/sales.md](reference/sales.md)  
**Product**：API 使用、功能、采纳 → 看 [reference/product.md](reference/product.md)  
**Marketing**：活动、归因、邮件 → 看 [reference/marketing.md](reference/marketing.md)

## Quick search

用 grep 找具体指标：

```bash
grep -i "revenue" reference/finance.md
grep -i "pipeline" reference/sales.md
grep -i "api usage" reference/product.md
```
```

#### 模式 3：条件式细节

先展示基础内容，再链接高级内容：

```markdown
# DOCX Processing

## Creating documents

新文档用 docx-js。看 [DOCX-JS.md](DOCX-JS.md)。

## Editing documents

简单编辑可以直接改 XML。

**跟踪更改**：看 [REDLINING.md](REDLINING.md)  
**OOXML 细节**：看 [OOXML.md](OOXML.md)
```

Claude 只会在用户需要这些功能时才读 `REDLINING.md` 或 `OOXML.md`。

### 避免过深的嵌套引用

Claude 可能会对被引用文件只做部分读取，尤其是引用链太深时。遇到嵌套引用，Claude 可能只用 `head -100` 预览，而不是整读，导致信息不完整。

**把引用保持在 `SKILL.md` 的一层深度。** 所有参考文件都应该直接从 `SKILL.md` 链接出去，这样 Claude 需要时才能完整读取。

**坏例子：太深**：

```markdown
# SKILL.md
See [advanced.md](advanced.md)...

# advanced.md
See [details.md](details.md)...

# details.md
Here's the actual information...
```

**好例子：一层深**：

```markdown
# SKILL.md

**Basic usage**：指向 `SKILL.md` 本体  
**Advanced features**：看 [advanced.md](advanced.md)  
**API reference**：看 [reference.md](reference.md)  
**Examples**：看 [examples.md](examples.md)
```

### 长参考文件要带目录

超过 100 行的参考文件，顶部要加目录。这样即使 Claude 只做部分预览，也能看出文件覆盖哪些内容。

**示例**：

```markdown
# API Reference

## Contents
- Authentication and setup
- Core methods (create, read, update, delete)
- Advanced features (batch operations, webhooks)
- Error handling patterns
- Code examples

## Authentication and setup
...

## Core methods
...
```

这样 Claude 既可以整读，也可以按需跳转到具体章节。

关于这套基于文件系统的架构如何支持渐进式披露，见下面高级部分里的 [Runtime environment](#runtime-environment)。

## 工作流与反馈循环

### 复杂任务要用工作流

把复杂操作拆成清晰、顺序明确的步骤。对特别复杂的流程，提供一个可直接复制到回复里的清单，让 Claude 可以边做边勾。

**示例 1：研究综合工作流**（无代码 Skill）：

````markdown
## Research synthesis workflow

Copy this checklist and track your progress:

```
Research Progress:
- [ ] Step 1: Read all source documents
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
- [ ] Step 4: Create structured summary
- [ ] Step 5: Verify citations
```

**Step 1: Read all source documents**

Review each document in the `sources/` directory. Note the main arguments and supporting evidence.

**Step 2: Identify key themes**

Look for patterns across sources. What themes appear repeatedly? Where do sources agree or disagree?

**Step 3: Cross-reference claims**

For each major claim, verify it appears in the source material. Note which source supports each point.

**Step 4: Create structured summary**

Organize findings by theme. Include:
- Main claim
- Supporting evidence from sources
- Conflicting viewpoints (if any)

**Step 5: Verify citations**

Check that every claim references the correct source document. If citations are incomplete, return to Step 3.
````

这个例子说明了工作流如何用于不需要代码的分析任务。清单模式适用于任何复杂、多步骤流程。

**示例 2：PDF 表单填写工作流**（有代码 Skill）：

````markdown
## PDF form filling workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Analyze the form (run analyze_form.py)
- [ ] Step 2: Create field mapping (edit fields.json)
- [ ] Step 3: Validate mapping (run validate_fields.py)
- [ ] Step 4: Fill the form (run fill_form.py)
- [ ] Step 5: Verify output (run verify_output.py)
```

**Step 1: Analyze the form**

Run: `python scripts/analyze_form.py input.pdf`

This extracts form fields and their locations, saving to `fields.json`.

**Step 2: Create field mapping**

Edit `fields.json` to add values for each field.

**Step 3: Validate mapping**

Run: `python scripts/validate_fields.py fields.json`

Fix any validation errors before continuing.

**Step 4: Fill the form**

Run: `python scripts/fill_form.py input.pdf fields.json output.pdf`

**Step 5: Verify output**

Run: `python scripts/verify_output.py output.pdf`

If verification fails, return to Step 2.
````

清晰的步骤能防止 Claude 跳过关键验证。清单帮助 Claude 和你都跟踪多步骤工作流。

### 实现反馈循环

**常见模式**：运行校验器 → 修复错误 → 重试

这个模式能大幅提高输出质量。

**示例 1：样式指南合规**（无代码 Skill）：

```markdown
## Content review process

1. Draft your content following the guidelines in STYLE_GUIDE.md
2. Review against the checklist:
   - Check terminology consistency
   - Verify examples follow the standard format
   - Confirm all required sections are present
3. If issues found:
   - Note each issue with specific section reference
   - Revise the content
   - Review the checklist again
4. Only proceed when all requirements are met
5. Finalize and save the document
```

这里用参考文档而不是脚本来构造验证循环。`STYLE_GUIDE.md` 就是“校验器”，Claude 通过阅读和对照来完成检查。

**示例 2：文档编辑流程**（有代码 Skill）：

```markdown
## Document editing process

1. Make your edits to `word/document.xml`
2. **Validate immediately**: `python ooxml/scripts/validate.py unpacked_dir/`
3. If validation fails:
   - Review the error message carefully
   - Fix the issues in the XML
   - Run validation again
4. **Only proceed when validation passes**
5. Rebuild: `python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. Test the output document
```

验证循环可以尽早抓住错误。

## 内容指南

### 避免时间敏感信息

不要包含会过期的信息：

**坏例子：时间敏感**（会变错）：

```markdown
If you're doing this before August 2025, use the old API.
After August 2025, use the new API.
```

**好例子**（用“旧模式”部分）：

```markdown
## Current method

Use the v2 API endpoint: `api.example.com/v2/messages`

## Old patterns

<details>
<summary>Legacy v1 API (deprecated 2025-08)</summary>

The v1 API used: `api.example.com/v1/messages`

This endpoint is no longer supported.
</details>
```

“旧模式”部分保留了历史上下文，但不会污染主内容。

### 使用一致的术语

在整个 Skill 里选一个词，并始终用它：

**好 - 一致**：

* 始终说 `API endpoint`
* 始终说 `field`
* 始终说 `extract`

**坏 - 不一致**：

* 混用 `API endpoint`、`URL`、`API route`、`path`
* 混用 `field`、`box`、`element`、`control`
* 混用 `extract`、`pull`、`get`、`retrieve`

一致性会帮助 Claude 理解并遵守说明。

## 常见模式

### 模板模式

为输出格式提供模板。严格程度要和需求匹配。

**对于严格要求**（例如 API 响应或数据格式）：

````markdown
## Report structure

ALWAYS use this exact template structure:

```markdown
# [Analysis Title]

## Executive summary
[One-paragraph overview of key findings]

## Key findings
- Finding 1 with supporting data
- Finding 2 with supporting data
- Finding 3 with supporting data

## Recommendations
1. Specific actionable recommendation
2. Specific actionable recommendation
```
````

**对于灵活指导**（适合留给 Claude 自适应）：

````markdown
## Report structure

Here is a sensible default format, but use your best judgment based on the analysis:

```markdown
# [Analysis Title]

## Executive summary
[Overview]

## Key findings
[Adapt sections based on what you discover]

## Recommendations
[Tailor to the specific context]
```

Adjust sections as needed for the specific analysis type.
````

### 示例模式

当输出质量取决于示例时，就像普通提示那样提供输入/输出对：

````markdown
## Commit message format

Generate commit messages following these examples:

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
```
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**Example 2:**
Input: Fixed bug where dates displayed incorrectly in reports
Output:
```
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

**Example 3:**
Input: Updated dependencies and refactored error handling
Output:
```
chore: update dependencies and refactor error handling

- Upgrade lodash to 4.17.21
- Standardize error response format across endpoints
```

Follow this style: type(scope): brief description, then detailed explanation.
````

示例比单纯描述更能清楚说明目标风格和细节层级。

### 条件式工作流模式

用决策点引导 Claude：

```markdown
## Document modification workflow

1. Determine the modification type:

   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow:
   - Use docx-js library
   - Build document from scratch
   - Export to .docx format

3. Editing workflow:
   - Unpack existing document
   - Modify XML directly
   - Validate after each change
   - Repack when complete
```

<Tip>
  如果工作流变得很大、步骤很多，可以把它拆成单独文件，并告诉 Claude 根据具体任务读相应文件。
</Tip>

## 评估与迭代

### 先构建评估

**先写评估，再写大量文档。** 这样可以确保你的 Skill 解决的是真问题，而不是想象中的问题。

**评估驱动开发：**

1. **找缺口**：在没有 Skill 的情况下，让 Claude 做代表性任务。记录具体失败或缺失上下文。
2. **建立评估**：构建三个测试这些缺口的场景。
3. **建立基线**：在没有 Skill 时衡量 Claude 的表现。
4. **写最小指令**：只写足以弥补缺口并通过评估的内容。
5. **迭代**：执行评估、对比基线、继续打磨。

这样能确保你是在解决实际问题，而不是提前预测一个未必会出现的需求。

**评估结构**：

```json
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages in the document without missing any pages",
    "Saves the extracted text to a file named output.txt in a clear, readable format"
  ]
}
```

<Note>
  这个示例展示的是一个带简单测试标准的数据驱动评估。我们目前没有内置运行这些评估的方式；用户可以自己建立评估系统。评估才是衡量 Skill 效果的事实依据。
</Note>

### 与 Claude 迭代开发 Skills

最有效的 Skill 开发流程本身就要用 Claude。让一个 Claude 实例（“Claude A”）帮你创建给另一个实例（“Claude B”）使用的 Skill。Claude A 负责设计和打磨说明，Claude B 在真实任务里测试它们。之所以有效，是因为 Claude 模型既懂如何写有效的代理指令，也懂代理需要什么信息。

**创建新 Skill：**

1. **先不用 Skill 完成一次任务**：和 Claude A 按正常提示处理问题。过程中会自然提供上下文、解释偏好、分享流程知识。注意哪些信息你会反复说。

2. **找出可复用模式**：任务完成后，识别那些对未来类似任务也有用的上下文。

   **示例**：如果你做的是一次 BigQuery 分析，可能会提供表名、字段定义、过滤规则（如“始终排除测试账号”）和常见查询模式。

3. **让 Claude A 创建 Skill**：“创建一个 Skill，捕捉我们刚才使用的 BigQuery 分析模式。把表结构、命名约定，以及过滤测试账号的规则包含进去。”

   <Tip>
     Claude 模型天生理解 Skill 格式和结构。你不需要特殊系统提示，也不需要一个“writing skills” Skill 来让 Claude 帮你创建 Skill。只要直接让 Claude 创建，它就会生成结构正确的 `SKILL.md`，包含合适的 frontmatter 和正文。
   </Tip>

4. **检查是否足够简洁**：确认 Claude A 没有加多余解释。可以问：“删掉关于 win rate 是什么的解释，Claude 已经知道了。”

5. **改进信息架构**：让 Claude A 更好地组织内容。例如：“把表结构单独放到一个参考文件里。以后我们可能会加更多表。”

6. **在相似任务上测试**：用 Claude B（加载了 Skill 的新实例）处理相关任务。观察它是否能找到正确的信息、正确应用规则、成功完成任务。

7. **根据观察继续迭代**：如果 Claude B 卡住或漏掉内容，就带着具体情况回到 Claude A：“Claude 使用这个 Skill 时忘了在 Q4 里按日期过滤。要不要加一节关于日期过滤模式？”

**迭代现有 Skill：**

同样的层级模式也适用于改进现有 Skill。你会在以下角色之间轮换：

* **和 Claude A 合作**（帮助你细化 Skill 的专家）
* **用 Claude B 测试**（实际执行工作的代理）
* **观察 Claude B 的行为**，把发现带回 Claude A

1. **在真实工作流里使用 Skill**：给 Claude B（已加载 Skill）真实任务，不要测试题。

2. **观察 Claude B 的行为**：记录它在哪些地方卡住、成功、或做了意外选择。

   **观察示例**：“我让 Claude B 生成区域销售报告时，它写出了查询，但忘了排除测试账号，尽管 Skill 里提到了这条规则。”

3. **回到 Claude A 改进**：把当前 `SKILL.md` 发给它，并描述你观察到的现象。可以问：“我注意到 Claude B 在做区域报告时忘了过滤测试账号。Skill 里提到过滤，但也许不够显眼？”

4. **查看 Claude A 的建议**：Claude A 可能建议重组内容，让规则更突出，使用更强的措辞（例如把“总是过滤”改成“MUST filter”），或者重写工作流部分。

5. **应用并测试修改**：按照 Claude A 的建议更新 Skill，然后在类似请求上再次测试 Claude B。

6. **根据使用继续循环**：随着新场景出现，持续“观察-改进-测试”循环。每次迭代都基于真实代理行为，而不是假设。

**收集团队反馈：**

1. 把 Skill 分享给队友并观察他们如何使用
2. 问：Skill 是否在预期时触发？说明是否清楚？还缺什么？
3. 把反馈整合进来，补上你自己使用模式里的盲点

**为什么这套方法有效**：Claude A 理解代理需求，你提供领域知识，Claude B 通过真实使用暴露缺口，而迭代优化则基于观察到的行为，而不是假设。

### 观察 Claude 如何浏览 Skills

在迭代 Skill 时，要注意 Claude 实际是怎么用它的。重点看：

* **意料之外的探索路径**：Claude 是否按你没想到的顺序读文件？这可能说明结构不够直观
* **遗漏的连接**：Claude 是否没跟上重要文件的引用？你的链接可能需要更明确
* **对某些部分过度依赖**：如果 Claude 反复读同一个文件，考虑是否应该把这些内容放回主 `SKILL.md`
* **被忽略的内容**：如果 Claude 从不访问某个附属文件，那它可能是多余的，或者在主说明里的信号不够强

根据这些观察来迭代，不要凭假设。`name` 和 `description` 尤其关键。Claude 会用它们判断当前任务是否该触发这个 Skill。要确保它们清楚描述 Skill 是什么，以及什么时候该用。

## 要避免的反模式

### 避免 Windows 风格路径

始终使用正斜杠，即使在 Windows 上也一样：

* ✓ **好**：`scripts/helper.py`、`reference/guide.md`
* ✗ **避免**：`scripts\\helper.py`、`reference\\guide.md`

Unix 风格路径可以跨平台工作，而 Windows 风格路径在 Unix 系统上会出错。

### 避免给太多选项

除非必要，不要一次给多个方案：

````markdown
**坏例子：选项太多**（会混乱）：
"你可以用 pypdf、pdfplumber、PyMuPDF、pdf2image，或者……"

**好例子：给一个默认方案**（保留逃生出口）：
"用于文本提取，使用 pdfplumber：
```python
import pdfplumber
```

如果是需要 OCR 的扫描版 PDF，则改用 pdf2image + pytesseract。"
````

## 高级：带可执行代码的 Skills

下面这些内容适用于包含可执行脚本的 Skill。如果你的 Skill 只有 Markdown 指令，可以跳到 [Checklist for effective Skills](#checklist-for-effective-skills)。

### 解决问题，不要甩锅

编写脚本时，自己处理错误，而不是把问题推回给 Claude。

**好例子：显式处理错误**：

```python
def process_file(path):
    """处理文件；如果文件不存在就创建它。"""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        # 与其失败，不如创建默认内容
        print(f"File {path} not found, creating default")
        with open(path, 'w') as f:
            f.write('')
        return ''
    except PermissionError:
        # 提供替代方案，而不是直接失败
        print(f"Cannot access {path}, using default")
        return ''
```

**坏例子：把问题丢给 Claude**：

```python
def process_file(path):
    # 直接失败，让 Claude 自己想办法
    return open(path).read()
```

配置参数也应该有理由并写清楚，避免“玄学常量”（Ousterhout 定律）。如果你自己都不知道值该设多少，Claude 又怎么判断？

**好例子：自解释**：

```python
# HTTP requests typically complete within 30 seconds
# Longer timeout accounts for slow connections
REQUEST_TIMEOUT = 30

# Three retries balances reliability vs speed
# Most intermittent failures resolve by the second retry
MAX_RETRIES = 3
```

**坏例子：魔法数字**：

```python
TIMEOUT = 47  # Why 47?
RETRIES = 5   # Why 5?
```

### 提供实用脚本

即使 Claude 能写脚本，预先提供脚本仍然有这些好处：

**实用脚本的好处：**

* 比生成代码更可靠
* 节省 token（不用把代码塞进上下文）
* 节省时间（不需要现场生成代码）
* 保证多次使用时的一致性

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=4bbc45f2c2e0bee9f2f0d5da669bad00" alt="把可执行脚本和指令文件一起打包" data-og-width="2048" width="2048" data-og-height="1154" height="1154" data-path="images/agent-skills-executable-scripts.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=9a04e6535a8467bfeea492e517de389f 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=e49333ad90141af17c0d7651cca7216b 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=954265a5df52223d6572b6214168c428 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=2ff7a2d8f2a83ee8af132b29f10150fd 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=48ab96245e04077f4d15e9170e081cfb 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0301a6c8b3ee879497cc5b5483177c90 2500w" />

上图展示了可执行脚本如何和指令文件协作。指令文件（`forms.md`）引用脚本，而 Claude 可以直接执行，不必把脚本内容加载进上下文。

**重要区别**：说明里要写清楚 Claude 应该：

* **执行脚本**（最常见）：“运行 `analyze_form.py` 提取字段”
* **把它当参考阅读**（复杂逻辑时）：“查看 `analyze_form.py` 了解字段提取算法”

对大多数实用脚本来说，优先执行更可靠、更高效。脚本执行如何工作，见下面的 [Runtime environment](#runtime-environment)。

**示例**：

````markdown
## Utility scripts

**analyze_form.py**: 从 PDF 中提取所有表单字段

```bash
python scripts/analyze_form.py input.pdf > fields.json
```

Output format:
```json
{
  "field_name": {"type": "text", "x": 100, "y": 200},
  "signature": {"type": "sig", "x": 150, "y": 500}
}
```

**validate_boxes.py**: 检查是否有重叠的边界框

```bash
python scripts/validate_boxes.py fields.json
# Returns: "OK" or lists conflicts
```

**fill_form.py**: 将字段值应用到 PDF

```bash
python scripts/fill_form.py input.pdf fields.json output.pdf
```
````

### 使用视觉分析

当输入可以渲染成图片时，让 Claude 分析它们：

````markdown
## Form layout analysis

1. Convert PDF to images:
   ```bash
   python scripts/pdf_to_images.py form.pdf
   ```

2. Analyze each page image to identify form fields
3. Claude can see field locations and types visually
````

<Note>
  在这个例子里，你需要自己编写 `pdf_to_images.py` 脚本。
</Note>

Claude 的视觉能力有助于理解布局和结构。

### 创建可验证的中间产物

当 Claude 执行复杂、开放式任务时，可能会出错。“计划-验证-执行”模式通过让 Claude 先用结构化格式创建计划，再用脚本验证计划，最后执行计划，来尽早发现错误。

**示例**：假设你让 Claude 根据电子表格更新 PDF 中的 50 个表单字段。没有验证时，Claude 可能引用不存在的字段、创建冲突值、漏掉必填字段，或者把更新应用错。

**解决方案**：使用上面那个工作流模式（PDF 表单填写），再加一个在应用变更前会先验证的中间 `changes.json` 文件。工作流就变成：分析 → **创建计划文件** → **验证计划** → 执行 → 验证。

**为什么这个模式有效：**

* **更早发现错误**：验证会在变更落地前发现问题
* **可机器验证**：脚本给出客观校验
* **规划可回滚**：Claude 可以在不碰原始文件的情况下反复调整计划
* **调试更清晰**：错误信息会指出具体问题

**何时使用**：批量操作、破坏性变更、复杂校验规则、高风险操作。

**实现建议**：把验证脚本写得更明确一些，提供具体错误信息，比如 `Field 'signature_date' not found. Available fields: customer_name, order_total, signature_date_signed`，这样 Claude 更容易修正问题。

### 包依赖

Skills 运行在带有平台限制的代码执行环境中：

* **claude.ai**：可以安装 npm 和 PyPI 包，也可以拉取 GitHub 仓库
* **Anthropic API**：没有网络访问，也不能在运行时安装包

在 `SKILL.md` 里列出所需包，并在 [code execution tool documentation](/en/docs/agents-and-tools/tool-use/code-execution-tool) 中确认它们可用。

### 运行时环境

Skills 运行在一个具备文件系统访问、bash 命令和代码执行能力的环境里。关于这个架构的概念说明，请参见概览中的 [The Skills architecture](/en/docs/agents-and-tools/agent-skills/overview#the-skills-architecture)。

**这会怎样影响编写：**

**Claude 如何访问 Skills：**

1. **元数据预加载**：启动时，所有 Skills 的 YAML frontmatter 中的 `name` 和 `description` 会被加载到系统提示词里
2. **文件按需读取**：Claude 会用 bash Read 工具在需要时读取 `SKILL.md` 和其他文件
3. **脚本可以高效执行**：实用脚本可以直接通过 bash 执行，不必把完整内容加载进上下文。只有脚本输出会消耗 token
4. **大文件不会立刻消耗上下文成本**：参考文件、数据或文档只有在真正被读取时才消耗 token

* **文件路径很重要**：Claude 会像操作文件系统一样浏览技能目录。请使用正斜杠（`reference/guide.md`），不要用反斜杠
* **文件命名要有描述性**：用能体现内容的名称，例如 `form_validation_rules.md`，不要用 `doc2.md`
* **按发现方式组织**：按领域或特性组织目录
  * 好：`reference/finance.md`、`reference/sales.md`
  * 坏：`docs/file1.md`、`docs/file2.md`
* **把完整资源打包进去**：可以包含完整 API 文档、大量示例、海量数据集；在被读取前不会消耗上下文 token
* **确定性操作优先用脚本**：写 `validate_form.py`，不要让 Claude 临时生成校验代码
* **明确执行意图：**
  * “运行 `analyze_form.py` 提取字段” （执行）
  * “查看 `analyze_form.py` 了解提取算法” （作为参考阅读）
* **测试文件访问模式**：用真实请求验证 Claude 是否能在目录结构里正确导航

**示例：**

```text
bigquery-skill/
├── SKILL.md (overview, points to reference files)
└── reference/
    ├── finance.md (revenue metrics)
    ├── sales.md (pipeline data)
    └── product.md (usage analytics)
```

当用户问收入时，Claude 会读 `SKILL.md`，看到 `reference/finance.md` 的引用，然后通过 bash 只读取那个文件。`sales.md` 和 `product.md` 会继续留在文件系统里，在真正需要前不消耗任何上下文 token。这种基于文件系统的模型，就是渐进式披露能成立的原因。

关于这套技术架构的完整细节，请参见技能概览中的 [How Skills work](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)。

### MCP 工具引用

如果你的 Skill 使用 MCP（Model Context Protocol）工具，请始终使用完整限定名，避免 “tool not found” 错误。

**格式**：`ServerName:tool_name`

**示例**：

```markdown
Use the BigQuery:bigquery_schema tool to retrieve table schemas.
Use the GitHub:create_issue tool to create issues.
```

其中：

* `BigQuery` 和 `GitHub` 是 MCP 服务器名称
* `bigquery_schema` 和 `create_issue` 是这些服务器里的工具名

如果没有服务器前缀，Claude 可能找不到工具，尤其是在有多个 MCP 服务器时。

### 避免假设工具已安装

不要假设包已经存在：

```markdown
**Bad example: Assumes installation**:
"Use the pdf library to process the file."

**Good example: Explicit about dependencies**:
"Install required package: `pip install pypdf`

Then use it:
```python
from pypdf import PdfReader
reader = PdfReader("file.pdf")
```"
```

## 技术说明

### YAML frontmatter 要求

`SKILL.md` 的 frontmatter 需要 `name`（最多 64 字符）和 `description`（最多 1024 字符）两个字段。完整结构请参见 [Skills overview](/en/docs/agents-and-tools/agent-skills/overview#skill-structure)。

### Token 预算

把 `SKILL.md` 正文控制在 500 行以内，能获得最佳性能。如果内容超过这个限制，就按前面说的渐进式披露模式拆到单独文件。关于架构细节，见 [Skills overview](/en/docs/agents-and-tools/agent-skills/overview#how-skills-work)。

## 有效 Skills 检查清单

分享 Skill 前，请确认：

### 核心质量

* [ ] description 足够具体，并包含关键术语
* [ ] description 同时写清楚 Skill 做什么以及何时使用
* [ ] `SKILL.md` 正文少于 500 行
* [ ] 如有需要，把额外细节放到单独文件里
* [ ] 没有时间敏感信息（或者已经放在“旧模式”部分）
* [ ] 全文术语一致
* [ ] 示例具体，不抽象
* [ ] 文件引用只深入一层
* [ ] 正确使用渐进式披露
* [ ] 工作流步骤清晰

### 代码和脚本

* [ ] 脚本是在解决问题，而不是把问题丢给 Claude
* [ ] 错误处理明确且有帮助
* [ ] 没有“玄学常量”（所有值都有理由）
* [ ] 必需包已列在说明中，并已验证可用
* [ ] 脚本文档清楚
* [ ] 没有 Windows 风格路径（全部用正斜杠）
* [ ] 关键操作有验证/校验步骤
* [ ] 对质量关键任务包含反馈循环

### 测试

* [ ] 至少创建了三个评估
* [ ] 分别在 Haiku、Sonnet 和 Opus 上测试过
* [ ] 用真实使用场景测试过
* [ ] 如适用，已吸收团队反馈

## 下一步

<CardGroup cols={2}>
  <Card title="开始使用 Agent Skills" icon="rocket" href="/en/docs/agents-and-tools/agent-skills/quickstart">
    创建你的第一个 Skill
  </Card>

  <Card title="在 Claude Code 中使用 Skills" icon="terminal" href="/en/docs/claude-code/skills">
    在 Claude Code 中创建和管理 Skills
  </Card>
</CardGroup>
