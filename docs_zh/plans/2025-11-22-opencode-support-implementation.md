# OpenCode 支持实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 superpowers:executing-plans 按任务逐项实现本计划。

**Goal:** 为 OpenCode.ai 增加完整的 superpowers 支持，采用原生 JavaScript 插件，并与现有 Codex 实现共享核心功能。

**Architecture:** 将通用的技能发现/解析逻辑提取到 `lib/skills-core.js`，重构 Codex 以使用它，然后借助 OpenCode 原生插件 API、自定义工具和 session hooks 构建 OpenCode 插件。

**Tech Stack:** Node.js、JavaScript、OpenCode Plugin API、Git worktrees

---

## Phase 1：创建共享核心模块

### Task 1：提取 Frontmatter 解析逻辑

**Files:**
- Create: `lib/skills-core.js`
- Reference: `.codex/superpowers-codex`（第 40-74 行）

**Step 1: 创建带 extractFrontmatter 函数的 lib/skills-core.js**

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Extract YAML frontmatter from a skill file.
 * Current format:
 * ---
 * name: skill-name
 * description: Use when [condition] - [what it does]
 * ---
 *
 * @param {string} filePath - Path to SKILL.md file
 * @returns {{name: string, description: string}}
 */
function extractFrontmatter(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');

        let inFrontmatter = false;
        let name = '';
        let description = '';

        for (const line of lines) {
            if (line.trim() === '---') {
                if (inFrontmatter) break;
                inFrontmatter = true;
                continue;
            }

            if (inFrontmatter) {
                const match = line.match(/^(\w+):\s*(.*)$/);
                if (match) {
                    const [, key, value] = match;
                    switch (key) {
                        case 'name':
                            name = value.trim();
                            break;
                        case 'description':
                            description = value.trim();
                            break;
                    }
                }
            }
        }

        return { name, description };
    } catch (error) {
        return { name: '', description: '' };
    }
}

module.exports = {
    extractFrontmatter
};
```

**Step 2: 验证文件已创建**

运行：`ls -l lib/skills-core.js`
预期：文件存在

**Step 3: 提交**

```bash
git add lib/skills-core.js
git commit -m "feat: create shared skills core module with frontmatter parser"
```

---

### Task 2：提取技能发现逻辑

**Files:**
- Modify: `lib/skills-core.js`
- Reference: `.codex/superpowers-codex`（第 97-136 行）

**Step 1: 向 skills-core.js 添加 findSkillsInDir 函数**

在 `module.exports` 之前添加：

```javascript
/**
 * Find all SKILL.md files in a directory recursively.
 *
 * @param {string} dir - Directory to search
 * @param {string} sourceType - 'personal' or 'superpowers' for namespacing
 * @param {number} maxDepth - Maximum recursion depth (default: 3)
 * @returns {Array<{path: string, name: string, description: string, sourceType: string}>}
 */
function findSkillsInDir(dir, sourceType, maxDepth = 3) {
    const skills = [];

    if (!fs.existsSync(dir)) return skills;

    function recurse(currentDir, depth) {
        if (depth > maxDepth) return;

        const entries = fs.readdirSync(currentDir, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(currentDir, entry.name);

            if (entry.isDirectory()) {
                // Check for SKILL.md in this directory
                const skillFile = path.join(fullPath, 'SKILL.md');
                if (fs.existsSync(skillFile)) {
                    const { name, description } = extractFrontmatter(skillFile);
                    skills.push({
                        path: fullPath,
                        skillFile: skillFile,
                        name: name || entry.name,
                        description: description || '',
                        sourceType: sourceType
                    });
                }

                // Recurse into subdirectories
                recurse(fullPath, depth + 1);
            }
        }
    }

    recurse(dir, 0);
    return skills;
}
```

**Step 2: 更新 module.exports**

将导出行替换为：

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir
};
```

**Step 3: 验证语法**

运行：`node -c lib/skills-core.js`
预期：无输出（成功）

**Step 4: 提交**

```bash
git add lib/skills-core.js
git commit -m "feat: add skill discovery function to core module"
```

---

### Task 3：提取技能解析逻辑

**Files:**
- Modify: `lib/skills-core.js`
- Reference: `.codex/superpowers-codex`（第 212-280 行）

**Step 1: 添加 resolveSkillPath 函数**

在 `module.exports` 之前添加：

```javascript
/**
 * Resolve a skill name to its file path, handling shadowing
 * (personal skills override superpowers skills).
 *
 * @param {string} skillName - Name like "superpowers:brainstorming" or "my-skill"
 * @param {string} superpowersDir - Path to superpowers skills directory
 * @param {string} personalDir - Path to personal skills directory
 * @returns {{skillFile: string, sourceType: string, skillPath: string} | null}
 */
function resolveSkillPath(skillName, superpowersDir, personalDir) {
    // Strip superpowers: prefix if present
    const forceSuperpowers = skillName.startsWith('superpowers:');
    const actualSkillName = forceSuperpowers ? skillName.replace(/^superpowers:/, '') : skillName;

    // Try personal skills first (unless explicitly superpowers:)
    if (!forceSuperpowers && personalDir) {
        const personalPath = path.join(personalDir, actualSkillName);
        const personalSkillFile = path.join(personalPath, 'SKILL.md');
        if (fs.existsSync(personalSkillFile)) {
            return {
                skillFile: personalSkillFile,
                sourceType: 'personal',
                skillPath: actualSkillName
            };
        }
    }

    // Try superpowers skills
    if (superpowersDir) {
        const superpowersPath = path.join(superpowersDir, actualSkillName);
        const superpowersSkillFile = path.join(superpowersPath, 'SKILL.md');
        if (fs.existsSync(superpowersSkillFile)) {
            return {
                skillFile: superpowersSkillFile,
                sourceType: 'superpowers',
                skillPath: actualSkillName
            };
        }
    }

    return null;
}
```

**Step 2: 更新 module.exports**

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir,
    resolveSkillPath
};
```

**Step 3: 验证语法**

运行：`node -c lib/skills-core.js`
预期：无输出

**Step 4: 提交**

```bash
git add lib/skills-core.js
git commit -m "feat: add skill path resolution with shadowing support"
```

---

### Task 4：提取更新检查逻辑

**Files:**
- Modify: `lib/skills-core.js`
- Reference: `.codex/superpowers-codex`（第 16-38 行）

**Step 1: 添加 checkForUpdates 函数**

在 requires 后添加：

```javascript
const { execSync } = require('child_process');
```

在 `module.exports` 之前添加：

```javascript
/**
 * Check if a git repository has updates available.
 *
 * @param {string} repoDir - Path to git repository
 * @returns {boolean} - True if updates are available
 */
function checkForUpdates(repoDir) {
    try {
        // Quick check with 3 second timeout to avoid delays if network is down
        const output = execSync('git fetch origin && git status --porcelain=v1 --branch', {
            cwd: repoDir,
            timeout: 3000,
            encoding: 'utf8',
            stdio: 'pipe'
        });

        // Parse git status output to see if we're behind
        const statusLines = output.split('\n');
        for (const line of statusLines) {
            if (line.startsWith('## ') && line.includes('[behind ')) {
                return true; // We're behind remote
            }
        }
        return false; // Up to date
    } catch (error) {
        // Network down, git error, timeout, etc. - don't block bootstrap
        return false;
    }
}
```

**Step 2: 更新 module.exports**

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir,
    resolveSkillPath,
    checkForUpdates
};
```

**Step 3: 验证语法**

运行：`node -c lib/skills-core.js`
预期：无输出

**Step 4: 提交**

```bash
git add lib/skills-core.js
git commit -m "feat: add git update checking to core module"
```

---

## Phase 2：重构 Codex 以使用共享核心

### Task 5：更新 Codex 以导入共享核心

**Files:**
- Modify: `.codex/superpowers-codex`（在顶部添加 import）

**Step 1: 添加 import 语句**

在文件顶部现有 requires 之后（大约第 6 行）添加：

```javascript
const skillsCore = require('../lib/skills-core');
```

**Step 2: 验证语法**

运行：`node -c .codex/superpowers-codex`
预期：无输出

**Step 3: 提交**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: import shared skills core in codex"
```

---

### Task 6：用核心版本替换 extractFrontmatter

**Files:**
- Modify: `.codex/superpowers-codex`（第 40-74 行）

**Step 1: 删除本地 extractFrontmatter 函数**

删除第 40-74 行（整个 extractFrontmatter 函数定义）。

**Step 2: 更新所有 extractFrontmatter 调用**

将所有 `extractFrontmatter(` 调用替换为 `skillsCore.extractFrontmatter(`

受影响行大约：90、310

**Step 3: 验证脚本仍可工作**

运行：`.codex/superpowers-codex find-skills | head -20`
预期：显示技能列表

**Step 4: 提交**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared extractFrontmatter in codex"
```

---

### Task 7：用核心版本替换 findSkillsInDir

**Files:**
- Modify: `.codex/superpowers-codex`（大约第 97-136 行）

**Step 1: 删除本地 findSkillsInDir 函数**

删除整个 `findSkillsInDir` 函数定义（大约第 97-136 行）。

**Step 2: 更新所有 findSkillsInDir 调用**

将 `findSkillsInDir(` 替换为 `skillsCore.findSkillsInDir(`

**Step 3: 验证脚本仍可工作**

运行：`.codex/superpowers-codex find-skills | head -20`
预期：显示技能列表

**Step 4: 提交**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared findSkillsInDir in codex"
```

---

### Task 8：用核心版本替换 checkForUpdates

**Files:**
- Modify: `.codex/superpowers-codex`（大约第 16-38 行）

**Step 1: 删除本地 checkForUpdates 函数**

删除整个 `checkForUpdates` 函数定义。

**Step 2: 更新所有 checkForUpdates 调用**

将 `checkForUpdates(` 替换为 `skillsCore.checkForUpdates(`

**Step 3: 验证脚本仍可工作**

运行：`.codex/superpowers-codex bootstrap | head -50`
预期：显示带说明的 bootstrap 内容

**Step 4: 提交**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared checkForUpdates in codex"
```

---

## Phase 3：构建 OpenCode 插件

### Task 9：创建 OpenCode 插件目录结构

**Files:**
- Create: `.opencode/plugin/superpowers.js`

**Step 1: 创建目录**

运行：`mkdir -p .opencode/plugin`

**Step 2: 创建基础插件文件**

```javascript
#!/usr/bin/env node

/**
 * Superpowers plugin for OpenCode.ai
 *
 * Provides custom tools for loading and discovering skills,
 * with automatic bootstrap on session start.
 */

const skillsCore = require('../../lib/skills-core');
const path = require('path');
const fs = require('fs');
const os = require('os');

const homeDir = os.homedir();
const superpowersSkillsDir = path.join(homeDir, '.config/opencode/superpowers/skills');
const personalSkillsDir = path.join(homeDir, '.config/opencode/skills');

/**
 * OpenCode plugin entry point
 */
export const SuperpowersPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    // Custom tools and hooks will go here
  };
};
```

**Step 3: 验证文件已创建**

运行：`ls -l .opencode/plugin/superpowers.js`
预期：文件存在

**Step 4: 提交**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: create opencode plugin scaffold"
```

---

### Task 10：实现 use_skill 工具

**Files:**
- Modify: `.opencode/plugin/superpowers.js`

**Step 1: 添加 use_skill 工具实现**

把插件 return 语句替换为：

```javascript
export const SuperpowersPlugin = async ({ project, client, $, directory, worktree }) => {
  // Import zod for schema validation
  const { z } = await import('zod');

  return {
    tools: [
      {
        name: 'use_skill',
        description: 'Load and read a specific skill to guide your work. Skills contain proven workflows, mandatory processes, and expert techniques.',
        schema: z.object({
          skill_name: z.string().describe('Name of the skill to load (e.g., "superpowers:brainstorming" or "my-custom-skill")')
        }),
        execute: async ({ skill_name }) => {
          // Resolve skill path (handles shadowing: personal > superpowers)
          const resolved = skillsCore.resolveSkillPath(
            skill_name,
            superpowersSkillsDir,
            personalSkillsDir
          );

          if (!resolved) {
            return `Error: Skill "${skill_name}" not found.\n\nRun find_skills to see available skills.`;
          }

          // Read skill content
          const fullContent = fs.readFileSync(resolved.skillFile, 'utf8');
          const { name, description } = skillsCore.extractFrontmatter(resolved.skillFile);

          // Extract content after frontmatter
          const lines = fullContent.split('\n');
          let inFrontmatter = false;
          let frontmatterEnded = false;
          const contentLines = [];

          for (const line of lines) {
            if (line.trim() === '---') {
              if (inFrontmatter) {
                frontmatterEnded = true;
                continue;
              }
              inFrontmatter = true;
              continue;
            }

            if (frontmatterEnded || !inFrontmatter) {
              contentLines.push(line);
            }
          }

          const content = contentLines.join('\n').trim();
          const skillDirectory = path.dirname(resolved.skillFile);

          // Format output similar to Claude Code's Skill tool
          return `# ${name || skill_name}
# ${description || ''}
# Supporting tools and docs are in ${skillDirectory}
# ============================================

${content}`;
        }
      }
    ]
  };
};
```

**Step 2: 验证语法**

运行：`node -c .opencode/plugin/superpowers.js`
预期：无输出

**Step 3: 提交**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement use_skill tool for opencode"
```

---

### Task 11：实现 find_skills 工具

**Files:**
- Modify: `.opencode/plugin/superpowers.js`

**Step 1: 向 tools 数组添加 find_skills 工具**

在 use_skill 工具定义之后、tools 数组结束之前添加：

```javascript
      {
        name: 'find_skills',
        description: 'List all available skills in the superpowers and personal skill libraries.',
        schema: z.object({}),
        execute: async () => {
          // Find skills in both directories
          const superpowersSkills = skillsCore.findSkillsInDir(
            superpowersSkillsDir,
            'superpowers',
            3
          );
          const personalSkills = skillsCore.findSkillsInDir(
            personalSkillsDir,
            'personal',
            3
          );

          // Combine and format skills list
          const allSkills = [...personalSkills, ...superpowersSkills];

          if (allSkills.length === 0) {
            return 'No skills found. Install superpowers skills to ~/.config/opencode/superpowers/skills/';
          }

          let output = 'Available skills:\n\n';

          for (const skill of allSkills) {
            const namespace = skill.sourceType === 'personal' ? '' : 'superpowers:';
            const skillName = skill.name || path.basename(skill.path);

            output += `${namespace}${skillName}\n`;
            if (skill.description) {
              output += `  ${skill.description}\n`;
            }
            output += `  Directory: ${skill.path}\n\n`;
          }

          return output;
        }
      }
```

**Step 2: 验证语法**

运行：`node -c .opencode/plugin/superpowers.js`
预期：无输出

**Step 3: 提交**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement find_skills tool for opencode"
```

---

### Task 12：实现 Session Start Hook

**Files:**
- Modify: `.opencode/plugin/superpowers.js`

**Step 1: 添加 session.started hook**

在 tools 数组之后添加：

```javascript
    'session.started': async () => {
      // Read using-superpowers skill content
      const usingSuperpowersPath = skillsCore.resolveSkillPath(
        'using-superpowers',
        superpowersSkillsDir,
        personalSkillsDir
      );

      let usingSuperpowersContent = '';
      if (usingSuperpowersPath) {
        const fullContent = fs.readFileSync(usingSuperpowersPath.skillFile, 'utf8');
        // Strip frontmatter
        const lines = fullContent.split('\n');
        let inFrontmatter = false;
        let frontmatterEnded = false;
        const contentLines = [];

        for (const line of lines) {
          if (line.trim() === '---') {
            if (inFrontmatter) {
              frontmatterEnded = true;
              continue;
            }
            inFrontmatter = true;
            continue;
          }

          if (frontmatterEnded || !inFrontmatter) {
            contentLines.push(line);
          }
        }

        usingSuperpowersContent = contentLines.join('\n').trim();
      }

      // Tool mapping instructions
      const toolMapping = `
**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`update_plan\` (your planning/task tracking tool)
- \`Task\` tool with subagents → Use OpenCode's subagent system (@mention syntax or automatic dispatch)
- \`Skill\` tool → \`use_skill\` custom tool (already available)
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Use your native tools

**Skill directories contain supporting files:**
- Scripts you can run with bash tool
- Additional documentation you can read
- Utilities and helpers specific to that skill

**Skills naming:**
- Superpowers skills: \`superpowers:skill-name\` (from ~/.config/opencode/superpowers/skills/)
- Personal skills: \`skill-name\` (from ~/.config/opencode/skills/)
- Personal skills override superpowers skills when names match
`;

      // Check for updates (non-blocking)
      const hasUpdates = skillsCore.checkForUpdates(
        path.join(homeDir, '.config/opencode/superpowers')
      );

      const updateNotice = hasUpdates ?
        '\n\n⚠️ **Updates available!** Run `cd ~/.config/opencode/superpowers && git pull` to update superpowers.' :
        '';

      // Return context to inject into session
      return {
        context: `<EXTREMELY_IMPORTANT>
You have superpowers.

**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'use_skill' tool:**

${usingSuperpowersContent}

${toolMapping}${updateNotice}
</EXTREMELY_IMPORTANT>`
      };
    }
```

**Step 2: 验证语法**

运行：`node -c .opencode/plugin/superpowers.js`
预期：无输出

**Step 3: 提交**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement session.started hook for opencode"
```

---

## Phase 4：文档

### Task 13：创建 OpenCode 安装指南

**Files:**
- Create: `.opencode/INSTALL.md`

**Step 1: 创建安装指南**

```markdown
# Installing Superpowers for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- Node.js installed
- Git installed

## Installation Steps

### 1. Install Superpowers Skills

```bash
# Clone superpowers skills to OpenCode config directory
mkdir -p ~/.config/opencode/superpowers
git clone https://github.com/obra/superpowers.git ~/.config/opencode/superpowers
```

### 2. Install the Plugin

The plugin is included in the superpowers repository you just cloned.

OpenCode will automatically discover it from:
- `~/.config/opencode/superpowers/.opencode/plugin/superpowers.js`

Or you can link it to the project-local plugin directory:

```bash
# In your OpenCode project
mkdir -p .opencode/plugin
ln -s ~/.config/opencode/superpowers/.opencode/plugin/superpowers.js .opencode/plugin/superpowers.js
```

### 3. Restart OpenCode

Restart OpenCode to load the plugin. On the next session, you should see:

```
You have superpowers.
```

## Usage

### Finding Skills

Use the `find_skills` tool to list all available skills:

```
use find_skills tool
```

### Loading a Skill

Use the `use_skill` tool to load a specific skill:

```
use use_skill tool with skill_name: "superpowers:brainstorming"
```

### Personal Skills

Create your own skills in `~/.config/opencode/skills/`:

```bash
mkdir -p ~/.config/opencode/skills/my-skill
```

Create `~/.config/opencode/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Use when [condition] - [what it does]
---

# My Skill

[Your skill content here]
```

Personal skills override superpowers skills with the same name.

## Updating

```bash
cd ~/.config/opencode/superpowers
git pull
```

## Troubleshooting

### Plugin not loading

1. Check plugin file exists: `ls ~/.config/opencode/superpowers/.opencode/plugin/superpowers.js`
2. Check OpenCode logs for errors
3. Verify Node.js is installed: `node --version`

### Skills not found

1. Verify skills directory exists: `ls ~/.config/opencode/superpowers/skills`
2. Use `find_skills` tool to see what's discovered
3. Check file structure: each skill should have a `SKILL.md` file

### Tool mapping issues

When a skill references a Claude Code tool you don't have:
- `TodoWrite` → use `update_plan`
- `Task` with subagents → use `@mention` syntax to invoke OpenCode subagents
- `Skill` → use `use_skill` tool
- File operations → use your native tools

## Getting Help

- Report issues: https://github.com/obra/superpowers/issues
- Documentation: https://github.com/obra/superpowers
```

**Step 2: 验证文件已创建**

运行：`ls -l .opencode/INSTALL.md`
预期：文件存在

**Step 3: 提交**

```bash
git add .opencode/INSTALL.md
git commit -m "docs: add opencode installation guide"
```

---

### Task 14：更新主 README

**Files:**
- Modify: `README.md`

**Step 1: 添加 OpenCode 章节**

找到关于支持平台的章节（在文件里搜索 “Codex”），然后在后面添加：

```markdown
### OpenCode

Superpowers works with [OpenCode.ai](https://opencode.ai) through a native JavaScript plugin.

**Installation:** See [.opencode/INSTALL.md](.opencode/INSTALL.md)

**Features:**
- Custom tools: `use_skill` and `find_skills`
- Automatic session bootstrap
- Personal skills with shadowing
- Supporting files and scripts access
```

**Step 2: 验证格式**

运行：`grep -A 10 "### OpenCode" README.md`
预期：显示你新增的章节

**Step 3: 提交**

```bash
git add README.md
git commit -m "docs: add opencode support to readme"
```

---

### Task 15：更新 Release Notes

**Files:**
- Modify: `RELEASE-NOTES.md`

**Step 1: 添加 OpenCode 支持条目**

在文件顶部（header 之后）添加：

```markdown
## [Unreleased]

### Added

- **OpenCode Support**: Native JavaScript plugin for OpenCode.ai
  - Custom tools: `use_skill` and `find_skills`
  - Automatic session bootstrap with tool mapping instructions
  - Shared core module (`lib/skills-core.js`) for code reuse
  - Installation guide in `.opencode/INSTALL.md`

### Changed

- **Refactored Codex Implementation**: Now uses shared `lib/skills-core.js` module
  - Eliminates code duplication between Codex and OpenCode
  - Single source of truth for skill discovery and parsing

---

```

**Step 2: 验证格式**

运行：`head -30 RELEASE-NOTES.md`
预期：显示你新增的章节

**Step 3: 提交**

```bash
git add RELEASE-NOTES.md
git commit -m "docs: add opencode support to release notes"
```

---

## Phase 5：最终验证

### Task 16：测试 Codex 仍然可用

**Files:**
- Test: `.codex/superpowers-codex`

**Step 1: 测试 find-skills 命令**

运行：`.codex/superpowers-codex find-skills | head -20`
预期：显示带名称和描述的技能列表

**Step 2: 测试 use-skill 命令**

运行：`.codex/superpowers-codex use-skill superpowers:brainstorming | head -20`
预期：显示 brainstorming 技能内容

**Step 3: 测试 bootstrap 命令**

运行：`.codex/superpowers-codex bootstrap | head -30`
预期：显示带说明的 bootstrap 内容

**Step 4: 若所有测试通过，记录成功**

无需提交，这只是验证。

---

### Task 17：验证文件结构

**Files:**
- Check: 所有新文件都存在

**Step 1: 验证所有文件已创建**

运行：
```bash
ls -l lib/skills-core.js
ls -l .opencode/plugin/superpowers.js
ls -l .opencode/INSTALL.md
```

预期：所有文件都存在

**Step 2: 验证目录结构**

运行：`tree -L 2 .opencode/`（如果没有 tree，可以用 `find .opencode -type f`）
预期：
```
.opencode/
├── INSTALL.md
└── plugin/
    └── superpowers.js
```

**Step 3: 如果结构正确，则继续**

无需提交，这只是验证。

---

### Task 18：最终提交与总结

**Files:**
- Check: `git status`

**Step 1: 检查 git status**

运行：`git status`
预期：工作树干净，所有变更都已提交

**Step 2: 查看提交日志**

运行：`git log --oneline -20`
预期：显示本次实现的所有提交

**Step 3: 创建总结文档**

创建一份完成总结，包含：
- 总共提交了多少次 commit
- 创建的文件：`lib/skills-core.js`、`.opencode/plugin/superpowers.js`、`.opencode/INSTALL.md`
- 修改的文件：`.codex/superpowers-codex`、`README.md`、`RELEASE-NOTES.md`
- 已执行的测试：Codex 命令验证
- 当前可进行：使用真实 OpenCode 安装进行测试

**Step 4: 汇报完成**

向用户展示总结，并提供以下选项：
1. 推送到远端
2. 创建 pull request
3. 使用真实 OpenCode 安装测试（需要已安装 OpenCode）

---

## 测试指南（手动，需要 OpenCode）

以下步骤要求已安装 OpenCode，不属于自动化实现的一部分：

1. **安装 skills**：按照 `.opencode/INSTALL.md`
2. **启动 OpenCode 会话**：验证 bootstrap 会出现
3. **测试 find_skills**：应列出所有可用技能
4. **测试 use_skill**：加载一个技能，并确认内容出现
5. **测试 supporting files**：验证技能目录路径可访问
6. **测试 personal skills**：创建一个 personal skill，并验证它会覆盖 core
7. **测试 tool mapping**：验证 TodoWrite → update_plan 映射正常工作

## 成功标准

- [ ] `lib/skills-core.js` 已创建，并包含所有核心函数
- [ ] `.codex/superpowers-codex` 已重构为使用共享核心
- [ ] Codex 命令仍然可用（find-skills、use-skill、bootstrap）
- [ ] `.opencode/plugin/superpowers.js` 已创建，并包含工具和 hooks
- [ ] 安装指南已创建
- [ ] README 和 RELEASE-NOTES 已更新
- [ ] 所有改动都已提交
- [ ] 工作树干净
