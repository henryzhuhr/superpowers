# OpenCode 支持设计

**Date:** 2025-11-22
**Author:** Bot & Jesse
**Status:** 设计完成，等待实现

## 概览

通过原生 OpenCode 插件架构为 OpenCode.ai 增加完整的 superpowers 支持，并与现有 Codex 实现共享核心功能。

## 背景

OpenCode.ai 是一个与 Claude Code 和 Codex 类似的编码 agent。此前将 superpowers 移植到 OpenCode 的尝试（PR #93、PR #116）采用的是文件复制方案。这个设计走的是另一条路：使用其 JavaScript/TypeScript 插件系统构建原生 OpenCode 插件，同时与 Codex 实现共享代码。

### 平台之间的关键差异

- **Claude Code**：原生 Anthropic 插件系统 + 基于文件的技能
- **Codex**：没有插件系统 → bootstrap markdown + CLI 脚本
- **OpenCode**：JavaScript/TypeScript 插件，带 event hooks 和自定义 tools API

### OpenCode 的 Agent 系统

- **Primary agents**：Build（默认，完全访问）和 Plan（受限，只读）
- **Subagents**：General（研究、搜索、多步骤任务）
- **调用方式**：由 primary agents 自动派发，或手动使用 `@mention` 语法
- **配置位置**：自定义 agents 放在 `opencode.json` 或 `~/.config/opencode/agent/`

## 架构

### 高层结构

1. **共享核心模块**（`lib/skills-core.js`）
   - 通用的技能发现和解析逻辑
   - 同时供 Codex 和 OpenCode 实现使用

2. **平台专用包装层**
   - Codex：CLI 脚本（`.codex/superpowers-codex`）
   - OpenCode：插件模块（`.opencode/plugin/superpowers.js`）

3. **技能目录**
   - Core：`~/.config/opencode/superpowers/skills/`（或安装位置）
   - Personal：`~/.config/opencode/skills/`（可覆盖 core 技能）

### 代码复用策略

把 `.codex/superpowers-codex` 中的通用功能提取到共享模块中：

```javascript
// lib/skills-core.js
module.exports = {
  extractFrontmatter(filePath),      // 从 YAML 解析 name + description
  findSkillsInDir(dir, maxDepth),    // 递归发现 SKILL.md
  findAllSkills(dirs),                // 扫描多个目录
  resolveSkillPath(skillName, dirs), // 处理覆盖逻辑（personal > core）
  checkForUpdates(repoDir)           // Git fetch/status 检查
};
```

### Skill Frontmatter 格式

当前格式（没有 `when_to_use` 字段）：

```yaml
---
name: skill-name
description: 在[条件]下使用 - [它的作用]；[附加上下文]
---
```

## OpenCode 插件实现

### 自定义工具

**工具 1：`use_skill`**

把指定技能的内容加载到对话中（等价于 Claude 的 Skill 工具）。

```javascript
{
  name: 'use_skill',
  description: 'Load and read a specific skill to guide your work',
  schema: z.object({
    skill_name: z.string().describe('Name of skill (e.g., "superpowers:brainstorming")')
  }),
  execute: async ({ skill_name }) => {
    const { skillPath, content, frontmatter } = resolveAndReadSkill(skill_name);
    const skillDir = path.dirname(skillPath);

    return `# ${frontmatter.name}
# ${frontmatter.description}
# Supporting tools and docs are in ${skillDir}
# ============================================

${content}`;
  }
}
```

**工具 2：`find_skills`**

列出所有可用技能及其元数据。

```javascript
{
  name: 'find_skills',
  description: 'List all available skills',
  schema: z.object({}),
  execute: async () => {
    const skills = discoverAllSkills();
    return skills.map(s =>
      `${s.namespace}:${s.name}
  ${s.description}
  Directory: ${s.directory}
`).join('\n');
  }
}
```

### 会话启动 Hook

当新会话开始时（`session.started` 事件）：

1. **注入 using-superpowers 内容**
   - 注入 using-superpowers 技能的完整内容
   - 用于建立强制工作流

2. **自动运行 find_skills**
   - 提前展示完整的可用技能列表
   - 为每个技能包含其目录

3. **注入工具映射说明**
   ```markdown
   **面向 OpenCode 的工具映射：**
   当技能引用你没有的工具时，做如下替换：
   - `TodoWrite` → `update_plan`
   - 带 subagent 的 `Task` → 使用 OpenCode subagent 系统（@mention）
   - `Skill` 工具 → `use_skill` 自定义工具
   - Read、Write、Edit、Bash → 你的原生等价工具

   **技能目录包含：**
   - Supporting scripts（用 bash 运行）
   - Additional documentation（用 read 工具读取）
   - Utilities specific to that skill
   ```

4. **检查更新**（非阻塞）
   - 带超时的快速 git fetch
   - 如果有更新则通知

### 插件结构

```javascript
// .opencode/plugin/superpowers.js
const skillsCore = require('../../lib/skills-core');
const path = require('path');
const fs = require('fs');
const { z } = require('zod');

export const SuperpowersPlugin = async ({ client, directory, $ }) => {
  const superpowersDir = path.join(process.env.HOME, '.config/opencode/superpowers');
  const personalDir = path.join(process.env.HOME, '.config/opencode/skills');

  return {
    'session.started': async () => {
      const usingSuperpowers = await readSkill('using-superpowers');
      const skillsList = await findAllSkills();
      const toolMapping = getToolMappingInstructions();

      return {
        context: `${usingSuperpowers}\n\n${skillsList}\n\n${toolMapping}`
      };
    },

    tools: [
      {
        name: 'use_skill',
        description: 'Load and read a specific skill',
        schema: z.object({
          skill_name: z.string()
        }),
        execute: async ({ skill_name }) => {
          // Implementation using skillsCore
        }
      },
      {
        name: 'find_skills',
        description: 'List all available skills',
        schema: z.object({}),
        execute: async () => {
          // Implementation using skillsCore
        }
      }
    ]
  };
};
```

## 文件结构

```
superpowers/
├── lib/
│   └── skills-core.js           # 新增：共享技能逻辑
├── .codex/
│   ├── superpowers-codex        # 已更新：使用 skills-core
│   ├── superpowers-bootstrap.md
│   └── INSTALL.md
├── .opencode/
│   ├── plugin/
│   │   └── superpowers.js       # 新增：OpenCode 插件
│   └── INSTALL.md               # 新增：安装指南
└── skills/                       # 不变
```

## 实施计划

### 第 1 阶段：重构共享核心

1. 创建 `lib/skills-core.js`
   - 从 `.codex/superpowers-codex` 提取 frontmatter 解析逻辑
   - 提取技能发现逻辑
   - 提取路径解析逻辑（含覆盖规则）
   - 更新为只使用 `name` 和 `description`（不再使用 `when_to_use`）

2. 更新 `.codex/superpowers-codex` 以使用共享核心
   - 从 `../lib/skills-core.js` 导入
   - 删除重复代码
   - 保留 CLI 包装层逻辑

3. 测试 Codex 实现仍然可用
   - 验证 bootstrap 命令
   - 验证 use-skill 命令
   - 验证 find-skills 命令

### 第 2 阶段：构建 OpenCode 插件

1. 创建 `.opencode/plugin/superpowers.js`
   - 从 `../../lib/skills-core.js` 导入共享核心
   - 实现插件函数
   - 定义自定义工具（use_skill、find_skills）
   - 实现 session.started hook

2. 创建 `.opencode/INSTALL.md`
   - 安装说明
   - 目录初始化
   - 配置指引

3. 测试 OpenCode 实现
   - 验证会话启动 bootstrap
   - 验证 use_skill 工具可用
   - 验证 find_skills 工具可用
   - 验证技能目录可访问

### 第 3 阶段：文档与收尾

1. 更新 README，加入 OpenCode 支持
2. 将 OpenCode 安装说明加入主文档
3. 更新 RELEASE-NOTES
4. 测试 Codex 和 OpenCode 都能正常工作

## 下一步

1. **创建隔离工作区**（使用 git worktrees）
   - 分支：`feature/opencode-support`

2. **在适用处遵循 TDD**
   - 测试共享核心函数
   - 测试技能发现与解析
   - 为两个平台编写集成测试

3. **增量实现**
   - 第 1 阶段：重构共享核心 + 更新 Codex
   - 在进入下一阶段前先验证 Codex 仍然可用
   - 第 2 阶段：构建 OpenCode 插件
   - 第 3 阶段：文档与收尾

4. **测试策略**
   - 使用真实 OpenCode 安装进行手工测试
   - 验证技能加载、目录和脚本是否正常
   - 并排测试 Codex 和 OpenCode
   - 验证工具映射是否正确工作

5. **PR 与合并**
   - 提交包含完整实现的 PR
   - 在干净环境中测试
   - 合并到 main

## 收益

- **代码复用**：技能发现/解析拥有单一事实来源
- **可维护性**：bug 修复能同时作用于两个平台
- **可扩展性**：未来更容易增加新平台（Cursor、Windsurf 等）
- **原生集成**：正确使用 OpenCode 的插件系统
- **一致性**：所有平台上拥有相同的技能体验
