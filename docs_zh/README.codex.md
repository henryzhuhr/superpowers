# 面向 Codex 的 Superpowers

通过原生技能发现机制在 OpenAI Codex 中使用 Superpowers 的指南。

## 快速安装

告诉 Codex：

```
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
```

## 手动安装

### 前置条件

- OpenAI Codex CLI
- Git

### 步骤

1. 克隆仓库：
   ```bash
   git clone https://github.com/obra/superpowers.git ~/.codex/superpowers
   ```

2. 创建 skills 符号链接：
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/superpowers/skills ~/.agents/skills/superpowers
   ```

3. 重启 Codex。

4. **对于 subagent 技能**（可选）：`dispatching-parallel-agents` 和 `subagent-driven-development` 等技能需要 Codex 的多智能体能力。向你的 Codex 配置中添加：
   ```toml
   [features]
   multi_agent = true
   ```

### Windows

使用 junction 而不是符号链接（无需启用 Developer Mode 也能工作）：

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\superpowers" "$env:USERPROFILE\.codex\superpowers\skills"
```

## 工作原理

Codex 原生支持技能发现，它会在启动时扫描 `~/.agents/skills/`，解析 `SKILL.md` frontmatter，并按需加载技能。Superpowers 技能通过一个符号链接暴露出来：

```
~/.agents/skills/superpowers/ → ~/.codex/superpowers/skills/
```

`using-superpowers` 技能会被自动发现，并负责约束技能使用纪律，不需要额外配置。

## 用法

技能会被自动发现。Codex 会在以下情况激活它们：
- 你按名称提到某个技能（例如，“use brainstorming”）
- 任务与某个技能的描述匹配
- `using-superpowers` 技能指示 Codex 使用某个技能

### 个人技能

在 `~/.agents/skills/` 中创建你自己的技能：

```bash
mkdir -p ~/.agents/skills/my-skill
```

创建 `~/.agents/skills/my-skill/SKILL.md`：

```markdown
---
name: my-skill
description: 在[条件]下使用 - [它的作用]
---

# 我的技能

[你的技能内容写在这里]
```

`description` 字段决定了 Codex 何时自动激活一个技能，所以要把它写成清晰的触发条件。

## 更新

```bash
cd ~/.codex/superpowers && git pull
```

技能会通过符号链接即时更新。

## 卸载

```bash
rm ~/.agents/skills/superpowers
```

**Windows（PowerShell）：**
```powershell
Remove-Item "$env:USERPROFILE\.agents\skills\superpowers"
```

也可以选择删除克隆目录：`rm -rf ~/.codex/superpowers`（Windows：`Remove-Item -Recurse -Force "$env:USERPROFILE\.codex\superpowers"`）。

## 故障排查

### 技能没有显示出来

1. 验证符号链接：`ls -la ~/.agents/skills/superpowers`
2. 检查技能是否存在：`ls ~/.codex/superpowers/skills`
3. 重启 Codex，技能会在启动时被发现

### Windows junction 问题

Junction 通常不需要特殊权限即可使用。如果创建失败，尝试以管理员身份运行 PowerShell。

## 获取帮助

- 报告问题：https://github.com/obra/superpowers/issues
- 主文档：https://github.com/obra/superpowers
