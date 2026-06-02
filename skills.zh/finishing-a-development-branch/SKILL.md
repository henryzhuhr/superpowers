---
name: finishing-a-development-branch
description: 适用于实现已完成、所有测试已通过，并且需要决定如何集成这些工作时使用 - 通过提供合并、创建 PR 或清理的结构化选项，指导开发工作的收尾
---

# 完成开发分支

## 概览

通过提供清晰的选项并执行所选流程，指导开发工作的收尾。

**核心原则：** 验证测试 → 提供选项 → 执行选择 → 清理。

**开始时先说明：** "我正在使用 finishing-a-development-branch skill 来完成这项工作。"

## 流程

### 第 1 步：验证测试

**在提供选项之前，先确认测试通过：**

```bash
# 运行项目的测试套件
npm test / cargo test / pytest / go test ./...
```

**如果测试失败：**
```
测试失败（<N> 个失败）。在完成之前必须先修复：

[显示失败信息]

在测试通过之前，不能继续进行合并/PR。
```

停止。不要进入第 2 步。

**如果测试通过：** 继续第 2 步。

### 第 2 步：确定基准分支

```bash
# 尝试常见的基准分支
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

或者询问： "这个分支是从 main 分出来的 - 这样理解对吗？"

### 第 3 步：提供选项

准确给出以下 4 个选项：

```
实现已完成。你希望怎么做？

1. 在本地合并回 <base-branch>
2. 推送并创建 Pull Request
3. 保持分支不变（我稍后处理）
4. 丢弃这项工作

请选择一个选项？
```

**不要添加解释** - 保持选项简洁。

### 第 4 步：执行选择

#### 选项 1：本地合并

```bash
# 切换到基准分支
git checkout <base-branch>

# 拉取最新内容
git pull

# 合并功能分支
git merge <feature-branch>

# 在合并结果上验证测试
<test command>

# 如果测试通过
git branch -d <feature-branch>
```

然后：清理 worktree（第 5 步）

#### 选项 2：推送并创建 PR

```bash
# 推送分支
git push -u origin <feature-branch>

# 创建 PR
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets of what changed>

## Test Plan
- [ ] <verification steps>
EOF
)"
```

然后：清理 worktree（第 5 步）

#### 选项 3：保持不变

回复： "保留分支 <name>。worktree 已保留在 <path>。"

**不要清理 worktree。**

#### 选项 4：丢弃

**先确认：**
```
这将永久删除：
- 分支 <name>
- 所有提交：<commit-list>
- 位于 <path> 的 worktree

请输入 'discard' 以确认。
```

等待精确确认。

如果已确认：
```bash
git checkout <base-branch>
git branch -D <feature-branch>
```

然后：清理 worktree（第 5 步）

### 第 5 步：清理 worktree

**对于选项 1、2、4：**

检查是否处于 worktree 中：
```bash
git worktree list | grep $(git branch --show-current)
```

如果是：
```bash
git worktree remove <worktree-path>
```

**对于选项 3：** 保留 worktree。

## 快速参考

| 选项 | 合并 | 推送 | 保留 Worktree | 清理分支 |
|--------|-------|------|---------------|----------------|
| 1. 本地合并 | ✓ | - | - | ✓ |
| 2. 创建 PR | - | ✓ | ✓ | - |
| 3. 保持不变 | - | - | ✓ | - |
| 4. 丢弃 | - | - | - | ✓（强制） |

## 常见错误

**跳过测试验证**
- **问题：** 合并有问题的代码，创建失败的 PR
- **修复：** 在提供选项之前，始终先验证测试

**开放式提问**
- **问题：** "接下来我该做什么？" → 含糊不清
- **修复：** 准确提供 4 个结构化选项

**自动清理 worktree**
- **问题：** 在可能还需要它的时候移除 worktree（选项 2、3）
- **修复：** 只在选项 1 和 4 时清理

**丢弃时没有确认**
- **问题：** 误删工作
- **修复：** 对选项 4 要求输入 "discard" 进行确认

## 红线

**绝不：**
- 在测试失败时继续
- 不验证合并结果就合并
- 未经确认就删除工作
- 未经明确请求就强制推送

**始终：**
- 在提供选项前验证测试
- 准确提供 4 个选项
- 对选项 4 获取输入确认
- 仅在选项 1 和 4 时清理 worktree

## 集成

**被以下 skill 调用：**
- **subagent-driven-development**（第 7 步）- 所有任务完成后
- **executing-plans**（第 5 步）- 所有批次完成后

**配合使用：**
- **using-git-worktrees** - 清理由该 skill 创建的 worktree
