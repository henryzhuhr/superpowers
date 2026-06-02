# 分层防御校验

## 概述

当你修复的是由无效数据引起的 bug 时，在一个地方加校验看起来就够了。但那一层检查可能被不同代码路径、重构或 mock 绕过。

**核心原则：** 在数据经过的每一层都做校验。让 bug 在结构上不可能发生。

## 为什么要多层

单层校验： “我们修好了 bug”
多层校验： “我们让 bug 不可能发生”

不同层能捕捉不同问题：
- 入口校验能抓住大多数 bug
- 业务逻辑能抓住边界情况
- 环境保护能阻止特定上下文中的危险操作
- 调试日志能在其他层失效时提供线索

## 四层防线

### 第 1 层：入口校验
**目的：** 在 API 边界拒绝明显非法的输入

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ... 继续
}
```

### 第 2 层：业务逻辑校验
**目的：** 确保这些数据对当前操作是合理的

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ... 继续
}
```

### 第 3 层：环境保护
**目的：** 防止特定上下文中的危险操作

```typescript
async function gitInit(directory: string) {
  // 在测试中，拒绝在临时目录之外执行 git init
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `Refusing git init outside temp dir during tests: ${directory}`
      );
    }
  }
  // ... 继续
}
```

### 第 4 层：调试埋点
**目的：** 为取证保留上下文

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... 继续
}
```

## 如何应用这个模式

当你发现一个 bug 时：

1. **追踪数据流** - 错误值从哪里来？在哪里被使用？
2. **标出所有检查点** - 列出数据经过的每个点
3. **在每一层加校验** - 入口、业务、环境、调试
4. **分别测试每一层** - 尝试绕过第 1 层，验证第 2 层能否拦住

## 来自会话的示例

Bug：空的 `projectDir` 导致 `git init` 在源码目录里执行

**数据流：**
1. 测试初始化 → 空字符串
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` 在 `process.cwd()` 中运行

**加入的四层防线：**
- 第 1 层：`Project.create()` 校验非空/存在/可写
- 第 2 层：`WorkspaceManager` 校验 projectDir 不能为空
- 第 3 层：`WorktreeManager` 在测试中拒绝在 tmpdir 之外执行 git init
- 第 4 层：在 git init 前记录堆栈跟踪

**结果：** 1847 个测试全部通过，bug 无法复现

## 关键洞察

这四层都很必要。测试时，每一层都能抓住其他层漏掉的问题：
- 不同代码路径会绕过入口校验
- mock 会绕过业务逻辑检查
- 不同平台上的边缘情况需要环境保护
- 调试日志能识别结构性误用

**不要停在一个校验点。** 要在每一层都加检查。
