---
name: using-git-worktrees
description: 适用于开始需要与当前工作区隔离的功能开发，或在执行实现计划之前使用 - 通过智能目录选择和安全校验创建隔离的 git worktree
---

# 使用 Git Worktree

## 概览

Git worktree 会创建彼此隔离、但共享同一仓库的工作区，从而允许你在不切换分支的情况下同时处理多个分支。

**核心原则：** 系统化的目录选择 + 安全校验 = 可靠的隔离。

**开始时先说明：** "我正在使用 `using-git-worktrees` skill 来设置一个隔离的工作区。"

## 目录选择流程

按照以下优先级执行：

### 1. 检查现有目录

```bash
# 按优先级检查
ls -d .worktrees 2>/dev/null     # 首选（隐藏）
ls -d worktrees 2>/dev/null      # 备选
```

**如果找到：** 使用该目录。如果两个都存在，优先使用 `.worktrees`。

### 2. 检查 CLAUDE.md

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**如果指定了偏好：** 直接使用，不要询问用户。

### 3. 询问用户

如果没有找到目录，且 `CLAUDE.md` 里也没有偏好：

```
未找到 worktree 目录。应该在哪里创建 worktree？

1. .worktrees/（项目内，隐藏）
2. ~/.config/superpowers/worktrees/<project-name>/（全局位置）

你更希望使用哪一个？
```

## 安全校验

### 对于项目内目录（.worktrees 或 worktrees）

**必须在创建 worktree 前验证目录已被忽略：**

```bash
# 检查目录是否被忽略（会尊重本地、全局和系统级 gitignore）
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**如果没有被忽略：**

按照 Jesse 的规则“立刻修复有问题的东西”：
1. 向 `.gitignore` 添加相应条目
2. 提交该改动
3. 继续创建 worktree

**为什么这很关键：** 防止不小心把 worktree 内容提交进仓库。

### 对于全局目录（~/.config/superpowers/worktrees）

不需要 `.gitignore` 校验，因为它不在项目目录中。

## 创建步骤

### 1. 检测项目名

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. 创建 Worktree

```bash
# 确定完整路径
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/superpowers/worktrees/*)
    path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    ;;
esac

# 使用新分支创建 worktree
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 3. 运行项目初始化

自动检测并运行合适的初始化命令：

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 4. 验证干净的基线

运行测试以确认 worktree 起始状态是干净的：

```bash
# 示例 - 使用适合项目的命令
npm test
cargo test
pytest
go test ./...
```

**如果测试失败：** 报告失败情况，并询问是否继续或进一步排查。

**如果测试通过：** 报告已经准备就绪。

### 5. 报告位置

```
Worktree 已就绪：<full-path>
测试通过（<N> 个测试，0 个失败）
可以开始实现 <feature-name>
```

## 快速参考

| 场景 | 操作 |
|-----------|--------|
| 存在 `.worktrees/` | 使用它（并验证已被忽略） |
| 存在 `worktrees/` | 使用它（并验证已被忽略） |
| 两者都存在 | 使用 `.worktrees/` |
| 两者都不存在 | 检查 CLAUDE.md → 询问用户 |
| 目录未被忽略 | 加入 `.gitignore` 并提交 |
| 基线测试失败 | 报告失败 + 询问 |
| 没有 `package.json`/`Cargo.toml` | 跳过依赖安装 |

## 常见错误

### 跳过忽略校验

- **问题：** worktree 内容会被跟踪，污染 git status
- **修复：** 在创建项目内 worktree 前，始终执行 `git check-ignore`

### 预设目录位置

- **问题：** 造成不一致，违反项目约定
- **修复：** 按优先级执行：现有目录 > CLAUDE.md > 询问

### 在测试失败时继续执行

- **问题：** 无法区分新 bug 和预先存在的问题
- **修复：** 报告失败，并获取明确许可后再继续

### 硬编码初始化命令

- **问题：** 在使用不同工具的项目中会失效
- **修复：** 根据项目文件自动检测（如 `package.json` 等）

## 示例流程

```
你：我正在使用 `using-git-worktrees` skill 来设置一个隔离的工作区。

[检查 .worktrees/ - 存在]
[验证已忽略 - git check-ignore 确认 .worktrees 被忽略]
[创建 worktree: git worktree add .worktrees/auth -b feature/auth]
[运行 npm install]
[运行 npm test - 47 个通过]

Worktree 已就绪：/Users/jesse/myproject/.worktrees/auth
测试通过（47 个测试，0 个失败）
可以开始实现 auth 功能
```

## 红线

**绝不要：**
- 在没有验证忽略状态的情况下创建 worktree（项目内目录）
- 跳过基线测试验证
- 在测试失败时不询问就继续
- 在目录选择不明确时自行假定位置
- 跳过 CLAUDE.md 检查

**始终要：**
- 遵循目录优先级：现有目录 > CLAUDE.md > 询问
- 对项目内目录验证是否已被忽略
- 自动检测并运行项目初始化
- 验证干净的测试基线

## 集成

**由以下技能调用：**
- **brainstorming**（第 4 阶段）- 设计获批且进入实现时必需
- **subagent-driven-development** - 执行任何任务前必需
- **executing-plans** - 执行任何任务前必需
- 任何需要隔离工作区的技能

**常搭配使用：**
- **finishing-a-development-branch** - 工作完成后的清理阶段必需
