# 测试 Superpowers 技能

本文说明如何测试 Superpowers 技能，尤其是像 `subagent-driven-development` 这样的复杂技能的集成测试。

## 概览

测试涉及 subagent、工作流和复杂交互的技能时，需要以无头模式运行真实的 Claude Code 会话，并通过会话转录验证其行为。

## 测试结构

```
tests/
├── claude-code/
│   ├── test-helpers.sh                    # 共享测试工具
│   ├── test-subagent-driven-development-integration.sh
│   ├── analyze-token-usage.py             # Token 用量分析工具
│   └── run-skill-tests.sh                 # 测试运行器（如果存在）
```

## 运行测试

### 集成测试

集成测试会携带真实技能执行真实的 Claude Code 会话：

```bash
# 运行 subagent-driven-development 集成测试
cd tests/claude-code
./test-subagent-driven-development-integration.sh
```

**注意：** 集成测试可能需要 10 到 30 分钟，因为它们会执行带多个 subagent 的真实实现计划。

### 要求

- 必须从 **superpowers 插件目录** 运行（不能从临时目录运行）
- 必须已安装 Claude Code，并且 `claude` 命令可用
- 必须启用本地开发 marketplace：在 `~/.claude/settings.json` 中设置 `"superpowers@superpowers-dev": true`

## 集成测试：subagent-driven-development

### 它测试什么

这个集成测试会验证 `subagent-driven-development` 技能是否正确做到：

1. **Plan Loading**：在开始时只读取一次计划
2. **Full Task Text**：向 subagent 提供完整任务描述（而不是让它们自己去读文件）
3. **Self-Review**：确保 subagent 在汇报前进行自检
4. **Review Order**：先执行规范符合性审查，再执行代码质量审查
5. **Review Loops**：发现问题时使用审查循环
6. **Independent Verification**：规范审查者会独立读取代码，而不是信任实现者的汇报

### 工作方式

1. **Setup**：创建一个带最小实现计划的临时 Node.js 项目
2. **Execution**：在无头模式下使用该技能运行 Claude Code
3. **Verification**：解析会话转录（`.jsonl` 文件）来验证：
   - 调用了 Skill 工具
   - 派发了 subagent（Task 工具）
   - 使用了 TodoWrite 进行跟踪
   - 创建了实现文件
   - 测试通过
   - Git 提交历史符合预期工作流
4. **Token Analysis**：展示各个 subagent 的 token 用量拆分

### 测试输出

```
========================================
 集成测试：subagent-driven-development
========================================

测试项目：/tmp/tmp.xyz123

=== 验证测试 ===

测试 1：Skill 工具已调用...
  [PASS] subagent-driven-development 技能已调用

测试 2：subagent 已派发...
  [PASS] 已派发 7 个 subagent

测试 3：任务跟踪...
  [PASS] TodoWrite 使用了 5 次

测试 6：实现验证...
  [PASS] 已创建 src/math.js
  [PASS] add 函数存在
  [PASS] multiply 函数存在
  [PASS] 已创建 test/math.test.js
  [PASS] 测试通过

测试 7：Git 提交历史...
  [PASS] 创建了多个提交（共 3 个）

测试 8：未添加额外功能...
  [PASS] 未添加额外功能

=========================================
 Token 用量分析
=========================================

用量拆分：
----------------------------------------------------------------------------------------------------
Agent           Description                          Msgs      Input     Output      Cache     Cost
----------------------------------------------------------------------------------------------------
main            主会话（协调者）                        34         27      3,996  1,213,703 $   4.09
3380c209        实现任务 1：创建 Add Function          1          2        787     24,989 $   0.09
34b00fde        实现任务 2：创建 Multiply Function     1          4        644     25,114 $   0.09
3801a732        审查某个实现是否匹配规范...             1          5        703     25,742 $   0.09
4c142934        执行最终代码审查...                     1          6        854     25,319 $   0.09
5f017a42        代码审查者。审查任务 2...               1          6        504     22,949 $   0.08
a6b7fbe4        代码审查者。审查任务 1...               1          6        515     22,534 $   0.08
f15837c0        审查某个实现是否匹配规范...             1          6        416     22,485 $   0.07
----------------------------------------------------------------------------------------------------

总计：
  总消息数：           41
  输入 token：         62
  输出 token：         8,419
  Cache 创建 token：   132,742
  Cache 读取 token：   1,382,835

  总输入（含 cache）： 1,515,639
  总 token：           1,524,058

  预估成本：$4.67
  （按输入/输出每百万 token 分别 $3/$15 计价）

========================================
 测试总结
========================================

状态：通过
```

## Token 分析工具

### 用法

分析任意 Claude Code 会话的 token 用量：

```bash
python3 tests/claude-code/analyze-token-usage.py ~/.claude/projects/<project-dir>/<session-id>.jsonl
```

### 查找会话文件

会话转录保存在 `~/.claude/projects/` 中，工作目录路径会被编码进目录名：

```bash
# /Users/jesse/Documents/GitHub/superpowers/superpowers 的示例
SESSION_DIR="$HOME/.claude/projects/-Users-jesse-Documents-GitHub-superpowers-superpowers"

# 查找最近的会话
ls -lt "$SESSION_DIR"/*.jsonl | head -5
```

### 它会展示什么

- **主会话用量**：协调者（你或主 Claude 实例）的 token 用量
- **按 subagent 拆分**：每次 Task 调用包含：
  - Agent ID
  - 描述（从 prompt 中提取）
  - 消息数
  - 输入/输出 token
  - Cache 用量
  - 预估成本
- **总计**：整体 token 用量和成本估算

### 如何理解输出

- **高 cache 读取量**：这是好事，说明 prompt cache 正在工作
- **主会话输入 token 很高**：这是预期行为，协调者拥有完整上下文
- **各 subagent 成本相近**：这是预期行为，每个 subagent 的任务复杂度相近
- **单任务成本**：典型范围是每个 subagent $0.05 到 $0.15，取决于任务内容

## 故障排查

### 技能未加载

**问题：** 运行无头测试时找不到技能

**解决方法：**
1. 确保你是从 superpowers 目录运行：`cd /path/to/superpowers && tests/...`
2. 检查 `~/.claude/settings.json` 的 `enabledPlugins` 中是否包含 `"superpowers@superpowers-dev": true`
3. 确认技能存在于 `skills/` 目录中

### 权限错误

**问题：** Claude 被阻止写文件或访问目录

**解决方法：**
1. 使用 `--permission-mode bypassPermissions` 参数
2. 使用 `--add-dir /path/to/temp/dir` 赋予测试目录访问权限
3. 检查测试目录的文件权限

### 测试超时

**问题：** 测试耗时过长并超时

**解决方法：**
1. 增加超时时间：`timeout 1800 claude ...`（30 分钟）
2. 检查技能逻辑中是否存在无限循环
3. 复查 subagent 任务复杂度

### 找不到会话文件

**问题：** 测试运行后找不到会话转录

**解决方法：**
1. 检查 `~/.claude/projects/` 下是否是正确的项目目录
2. 使用 `find ~/.claude/projects -name "*.jsonl" -mmin -60` 查找最近的会话
3. 确认测试确实已经运行（检查测试输出中是否有错误）

## 编写新的集成测试

### 模板

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

# 创建测试项目
TEST_PROJECT=$(create_test_project)
trap "cleanup_test_project $TEST_PROJECT" EXIT

# 设置测试文件...
cd "$TEST_PROJECT"

# 携带技能运行 Claude
PROMPT="Your test prompt here"
cd "$SCRIPT_DIR/../.." && timeout 1800 claude -p "$PROMPT" \
  --allowed-tools=all \
  --add-dir "$TEST_PROJECT" \
  --permission-mode bypassPermissions \
  2>&1 | tee output.txt

# 查找并分析会话
WORKING_DIR_ESCAPED=$(echo "$SCRIPT_DIR/../.." | sed 's/\\//-/g' | sed 's/^-//')
SESSION_DIR="$HOME/.claude/projects/$WORKING_DIR_ESCAPED"
SESSION_FILE=$(find "$SESSION_DIR" -name "*.jsonl" -type f -mmin -60 | sort -r | head -1)

# 通过解析会话转录来验证行为
if grep -q '"name":"Skill".*"skill":"your-skill-name"' "$SESSION_FILE"; then
    echo "[PASS] 技能已调用"
fi

# 展示 token 分析
python3 "$SCRIPT_DIR/analyze-token-usage.py" "$SESSION_FILE"
```

### 最佳实践

1. **始终清理**：使用 trap 清理临时目录
2. **解析转录**：不要 grep 面向用户的输出，要解析 `.jsonl` 会话文件
3. **授予权限**：使用 `--permission-mode bypassPermissions` 和 `--add-dir`
4. **从插件目录运行**：只有从 superpowers 目录运行时技能才会加载
5. **展示 token 用量**：始终附带 token 分析，便于观察成本
6. **测试真实行为**：验证实际创建的文件、测试是否通过、是否生成提交

## 会话转录格式

会话转录是 JSONL（JSON Lines）文件，每一行都是一个 JSON 对象，表示一条消息或工具结果。

### 关键字段

```json
{
  "type": "assistant",
  "message": {
    "content": [...],
    "usage": {
      "input_tokens": 27,
      "output_tokens": 3996,
      "cache_read_input_tokens": 1213703
    }
  }
}
```

### 工具结果

```json
{
  "type": "user",
  "toolUseResult": {
    "agentId": "3380c209",
    "usage": {
      "input_tokens": 2,
      "output_tokens": 787,
      "cache_read_input_tokens": 24989
    },
    "prompt": "You are implementing Task 1...",
    "content": [{"type": "text", "text": "..."}]
  }
}
```

`agentId` 字段用于关联 subagent 会话，`usage` 字段包含该次 subagent 调用的 token 用量信息。
