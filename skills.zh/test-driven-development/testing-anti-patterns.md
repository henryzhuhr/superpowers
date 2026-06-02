# 测试反模式

**在以下场景加载这个参考：** 编写或修改测试、添加 mock，或者你想给生产代码加只给测试用的方法时。

## 概述

测试必须验证真实行为，而不是验证 mock 的行为。mock 的作用是隔离，而不是被测试的对象。

**核心原则：测试代码实际做了什么，而不是 mock 做了什么。**

**严格遵循 TDD 可以避免这些反模式。**

## 铁律

```
1. 永远不要测试 mock 的行为
2. 永远不要给生产类添加只给测试用的方法
3. 永远不要在不了解依赖的情况下就去 mock
```

## 反模式 1：测试 mock 的行为

**违规示例：**
```typescript
// ❌ BAD: Testing that the mock exists
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
});
```

**为什么这是错的：**
- 你验证的是 mock 是否工作，而不是组件是否工作
- 只要 mock 在，测试就通过；mock 不在，测试就失败
- 这对真实行为没有任何说明

**人类协作方的纠正：** “我们是在测试 mock 的行为吗？”

**修正方式：**
```typescript
// ✅ GOOD: Test real component or don't mock it
test('renders sidebar', () => {
  render(<Page />);  // Don't mock sidebar
  expect(screen.getByRole('navigation')).toBeInTheDocument();
});

// OR if sidebar must be mocked for isolation:
// Don't assert on the mock - test Page's behavior with sidebar present
```

### 门禁函数

```
在对任何 mock 元素做断言之前：
  先问：“我是在测试真实组件行为，还是只是在测试 mock 是否存在？”

  如果是在测试 mock 是否存在：
    停下 - 删除这个断言，或者取消对该组件的 mock

  改为测试真实行为
```

## 反模式 2：在生产代码里加只给测试用的方法

**违规示例：**
```typescript
// ❌ BAD: destroy() only used in tests
class Session {
  async destroy() {  // Looks like production API!
    await this._workspaceManager?.destroyWorkspace(this.id);
    // ... cleanup
  }
}

// In tests
afterEach(() => session.destroy());
```

**为什么这是错的：**
- 生产类被测试专用代码污染了
- 如果在生产环境里被误调用，会很危险
- 违背了 YAGNI 和关注点分离
- 混淆了对象生命周期和实体生命周期

**修正方式：**
```typescript
// ✅ GOOD: Test utilities handle test cleanup
// Session has no destroy() - it's stateless in production

// In test-utils/
export async function cleanupSession(session: Session) {
  const workspace = session.getWorkspaceInfo();
  if (workspace) {
    await workspaceManager.destroyWorkspace(workspace.id);
  }
}

// In tests
afterEach(() => cleanupSession(session));
```

### 门禁函数

```
在给生产类添加任何方法之前：
  先问：“这是不是只被测试使用？”

  如果是：
    停下 - 不要加
    把它放到测试工具里

  再问：“这个类是否拥有这个资源的生命周期？”

  如果不是：
    停下 - 这不是放这个方法的正确类
```

## 反模式 3：在不了解依赖的情况下就去 mock

**违规示例：**
```typescript
// ❌ BAD: Mock breaks test logic
test('detects duplicate server', () => {
  // Mock prevents config write that test depends on!
  vi.mock('ToolCatalog', () => ({
    discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
  }));

  await addServer(config);
  await addServer(config);  // Should throw - but won't!
});
```

**为什么这是错的：**
- 被 mock 的方法有测试依赖的副作用（写配置）
- 为了“安全”而过度 mock，破坏了真实行为
- 测试可能因为错误原因通过，或者莫名其妙失败

**修正方式：**
```typescript
// ✅ GOOD: Mock at correct level
test('detects duplicate server', () => {
  // Mock the slow part, preserve behavior test needs
  vi.mock('MCPServerManager'); // Just mock slow server startup

  await addServer(config);  // Config written
  await addServer(config);  // Duplicate detected ✓
});
```

### 门禁函数

```
在 mock 任何方法之前：
  先停下 - 不要立刻 mock

  1. 问：“真实方法有哪些副作用？”
  2. 问：“这个测试是否依赖其中任何一个副作用？”
  3. 问：“我是否完全理解这个测试需要什么？”

  如果依赖副作用：
    在更低层进行 mock（实际慢/外部操作）
    或者使用能保留必要行为的测试替身
    不要 mock 这个测试依赖的高层方法

  如果不确定测试依赖什么：
    先用真实实现运行测试
    观察到底需要发生什么
    然后再在正确的层级做最小 mock

  红旗：
    - “我先 mock 一下，稳妥点”
    - “这个可能很慢，最好 mock”
    - 在不了解依赖链的情况下就 mock
```

## 反模式 4：不完整的 mock

**违规示例：**
```typescript
// ❌ BAD: Partial mock - only fields you think you need
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' }
  // Missing: metadata that downstream code uses
};

// Later: breaks when code accesses response.metadata.requestId
```

**为什么这是错的：**
- **部分 mock 会隐藏结构上的假设** - 你只 mock 了你知道的字段
- **下游代码可能依赖你没包含的字段** - 造成静默失败
- **测试通过，但集成失败** - mock 不完整，真实 API 是完整的
- **产生错误信心** - 测试并不能证明什么真实行为

**铁律：** mock 必须完整镜像现实中的数据结构，而不是只包含你当前测试用到的字段。

**修正方式：**
```typescript
// ✅ GOOD: Mirror real API completeness
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' },
  metadata: { requestId: 'req-789', timestamp: 1234567890 }
  // All fields real API returns
};
```

### 门禁函数

```
在创建 mock 响应之前：
  检查：“真实 API 响应包含哪些字段？”

  动作：
    1. 查阅文档/示例中的真实 API 响应
    2. 包含系统下游可能消费的所有字段
    3. 确认 mock 与真实响应 schema 完整匹配

  关键点：
    如果你要创建 mock，就必须理解完整结构
    部分 mock 会在代码依赖被省略字段时静默失败

  如果不确定：把文档里列出的字段都包含进去
```

## 反模式 5：把集成测试当成事后补充

**违规示例：**
```
✅ 实现完成
❌ 没有写测试
“准备测试了”
```

**为什么这是错的：**
- 测试是实现的一部分，不是可选的后续步骤
- TDD 本来就应该在这里拦住你
- 没有测试就不能算完成

**修正方式：**
```
TDD 循环：
1. 先写失败的测试
2. 实现让它通过
3. 重构
4. 然后才可以说完成
```

## 当 mock 变得过于复杂

**危险信号：**
- mock 的设置比测试逻辑还长
- 为了让测试通过而把所有东西都 mock 掉
- mock 缺少真实组件拥有的方法
- mock 变化时测试也跟着坏掉

**人类协作方的问题：** “这里真的需要用 mock 吗？”

**考虑一下：** 使用真实组件的集成测试通常比复杂 mock 更简单

## TDD 如何避免这些反模式

**TDD 的帮助：**
1. **先写测试** → 迫使你思考自己到底在测试什么
2. **亲眼看着它失败** → 确认测试的是真实行为，而不是 mock
3. **最小实现** → 不会悄悄混入只给测试用的方法
4. **真实依赖** → 你会在 mock 之前先看到测试真正需要什么

**如果你在测试 mock 的行为，你就违反了 TDD** - 你是在没有先看着测试对真实代码失败的情况下就加入了 mock。

## 快速参考

| 反模式 | 修正方式 |
|--------------|-----|
| 对 mock 元素断言 | 测试真实组件，或者取消 mock |
| 在生产代码里放只给测试用的方法 | 移到测试工具里 |
| 在不了解情况下就 mock | 先理解依赖，再最小化 mock |
| 不完整的 mock | 完整镜像真实 API |
| 把测试当成事后补充 | TDD - 先测试 |
| 过于复杂的 mock | 考虑集成测试 |

## 红旗

- 断言检查的是 `*-mock` 的 test ID
- 方法只在测试文件里被调用
- mock 设置占了测试的大半部分
- 取消 mock 后测试就失败
- 说不清为什么需要这个 mock
- 为了“稳妥”而去 mock

## 结论

**mock 是用来隔离的工具，不是拿来测试的对象。**

如果 TDD 让你发现自己在测试 mock 的行为，那你就走偏了。

修正方法：测试真实行为，或者重新思考你为什么要 mock。
