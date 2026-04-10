# 面向 OpenCode 的 Superpowers

在 [OpenCode.ai](https://opencode.ai) 中使用 Superpowers 的完整指南。

## 安装

将 superpowers 添加到你的 `opencode.json`（全局或项目级）的 `plugin` 数组中：

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

重启 OpenCode。插件会通过 Bun 自动安装，并自动注册所有技能。

可以通过提问来验证："Tell me about your superpowers"

### 从旧的基于符号链接的安装方式迁移

如果你之前通过 `git clone` 和符号链接安装过 superpowers，请移除旧配置：

```bash
# 删除旧的符号链接
rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers

# 可选：删除克隆的仓库
rm -rf ~/.config/opencode/superpowers

# 如果你曾为 superpowers 添加过 skills.paths，也请从 opencode.json 中移除
```

然后按上面的安装步骤进行安装。

## 用法

### 查找技能

使用 OpenCode 原生的 `skill` 工具列出所有可用技能：

```
use skill tool to list skills
```

### 加载一个技能

```
use skill tool to load superpowers/brainstorming
```

### 个人技能

在 `~/.config/opencode/skills/` 中创建你自己的技能：

```bash
mkdir -p ~/.config/opencode/skills/my-skill
```

创建 `~/.config/opencode/skills/my-skill/SKILL.md`：

```markdown
---
name: my-skill
description: 在[条件]下使用 - [它的作用]
---

# 我的技能

[你的技能内容写在这里]
```

### 项目技能

在项目内的 `.opencode/skills/` 中创建项目专属技能。

**技能优先级：** 项目技能 > 个人技能 > Superpowers 技能

## 更新

每次重启 OpenCode 时，Superpowers 都会自动更新。插件会在每次启动时从 git 仓库重新安装。

如果想固定某个特定版本，可以使用分支或标签：

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git#v5.0.3"]
}
```

## 工作原理

这个插件做两件事：

1. 通过 `experimental.chat.system.transform` hook 注入 bootstrap 上下文，让每次对话都具备 superpowers 感知。
2. 通过 `config` hook 注册技能目录，使 OpenCode 无需符号链接或手动配置就能发现所有 superpowers 技能。

### 工具映射

为 Claude Code 编写的技能会被自动适配到 OpenCode：

- `TodoWrite` → `todowrite`
- 带 subagent 的 `Task` → OpenCode 的 `@mention` 机制
- `Skill` 工具 → OpenCode 原生的 `skill` 工具
- 文件操作 → OpenCode 原生工具

## 故障排查

### 插件未加载

1. 检查 OpenCode 日志：`opencode run --print-logs "hello" 2>&1 | grep -i superpowers`
2. 确认 `opencode.json` 中的插件配置行正确
3. 确保你运行的是较新的 OpenCode 版本

### 找不到技能

1. 使用 OpenCode 的 `skill` 工具列出可用技能
2. 检查插件是否已加载（见上文）
3. 每个技能都需要带有有效 YAML frontmatter 的 `SKILL.md` 文件

### Bootstrap 没有出现

1. 检查 OpenCode 版本是否支持 `experimental.chat.system.transform` hook
2. 在修改配置后重启 OpenCode

## 获取帮助

- 报告问题：https://github.com/obra/superpowers/issues
- 主文档：https://github.com/obra/superpowers
- OpenCode 文档：https://opencode.ai/docs/
