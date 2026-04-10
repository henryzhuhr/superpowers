# 视觉化 Brainstorming 重构实施计划

> **For agentic workers:** REQUIRED: 使用 superpowers:subagent-driven-development（如果有 subagent）或 superpowers:executing-plans 来实现本计划。步骤使用 checkbox（`- [ ]`）语法进行跟踪。

**Goal:** 将 visual brainstorming 从阻塞式 TUI 反馈模型重构为非阻塞的 “Browser Displays, Terminal Commands” 架构。

**Architecture:** 浏览器变成交互式展示层，终端保持为对话通道。服务端将用户事件写入每个 screen 独有的 `.events` 文件，Claude 在下一轮 turn 中读取。彻底去掉 `wait-for-feedback.sh` 和所有 `TaskOutput` 阻塞。

**Tech Stack:** Node.js（Express、ws、chokidar）、原生 HTML/CSS/JS

**Spec:** `docs/superpowers/specs/2026-02-19-visual-brainstorming-refactor-design.md`

---

## 文件映射

| 文件 | 动作 | 责任 |
|------|--------|---------------|
| `lib/brainstorm-server/index.js` | 修改 | Server：添加 `.events` 文件写入、新 screen 时清空、替换 `wrapInFrame` |
| `lib/brainstorm-server/frame-template.html` | 修改 | Template：移除反馈 footer，添加内容占位符 + 选择指示器 |
| `lib/brainstorm-server/helper.js` | 修改 | Client JS：移除 send/feedback 函数，收窄为点击捕获 + 指示器更新 |
| `lib/brainstorm-server/wait-for-feedback.sh` | 删除 | 不再需要 |
| `skills/brainstorming/visual-companion.md` | 修改 | 技能说明：将 loop 重写为非阻塞流程 |
| `tests/brainstorm-server/server.test.js` | 修改 | 测试：更新以匹配新的模板结构和 helper.js API |

---

## Chunk 1：Server、Template、Client、Tests、Skill

### Task 1：更新 `frame-template.html`

**Files:**
- Modify: `lib/brainstorm-server/frame-template.html`

- [ ] **Step 1: 移除反馈 footer HTML**

用一个选择指示栏替换 feedback-footer div（第 227-233 行）：

```html
  <div class="indicator-bar">
    <span id="indicator-text">Click an option above, then return to the terminal</span>
  </div>
```

同时把 `#claude-content` 中的默认内容（第 220-223 行）替换为内容占位符：

```html
    <div id="claude-content">
      <!-- CONTENT -->
    </div>
```

- [ ] **Step 2: 用 indicator bar CSS 替换 feedback footer CSS**

移除 `.feedback-footer`、`.feedback-footer label`、`.feedback-row` 以及 `.feedback-footer` 内的 textarea/button 样式（第 82-112 行）。

添加 indicator bar CSS：

```css
    .indicator-bar {
      background: var(--bg-secondary);
      border-top: 1px solid var(--border);
      padding: 0.5rem 1.5rem;
      flex-shrink: 0;
      text-align: center;
    }
    .indicator-bar span {
      font-size: 0.75rem;
      color: var(--text-secondary);
    }
    .indicator-bar .selected-text {
      color: var(--accent);
      font-weight: 500;
    }
```

- [ ] **Step 3: 验证模板能正常渲染**

运行测试套件，检查模板仍然能加载：
```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：测试 1-5 仍然通过。测试 6-8 可能失败（这是预期的，因为它们还在断言旧结构）。

- [ ] **Step 4: 提交**

```bash
git add lib/brainstorm-server/frame-template.html
git commit -m "Replace feedback footer with selection indicator bar in brainstorm template"
```

---

### Task 2：更新 `index.js`，引入内容注入和 `.events` 文件

**Files:**
- Modify: `lib/brainstorm-server/index.js`

- [ ] **Step 1: 为 `.events` 文件写入先写一个失败测试**

在 `tests/brainstorm-server/server.test.js` 中 Test 4 附近后面加一个新测试，发送带 `choice` 字段的 WebSocket 事件，并验证 `.events` 文件被写入：

```javascript
    // Test: Choice events written to .events file
    console.log('Test: Choice events written to .events file');
    const ws3 = new WebSocket(`ws://localhost:${TEST_PORT}`);
    await new Promise(resolve => ws3.on('open', resolve));

    ws3.send(JSON.stringify({ type: 'click', choice: 'a', text: 'Option A' }));
    await sleep(300);

    const eventsFile = path.join(TEST_DIR, '.events');
    assert(fs.existsSync(eventsFile), '.events file should exist after choice click');
    const lines = fs.readFileSync(eventsFile, 'utf-8').trim().split('\n');
    const event = JSON.parse(lines[lines.length - 1]);
    assert.strictEqual(event.choice, 'a', 'Event should contain choice');
    assert.strictEqual(event.text, 'Option A', 'Event should contain text');
    ws3.close();
    console.log('  PASS');
```

- [ ] **Step 2: 运行测试，确认它失败**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：新测试失败，因为 `.events` 文件还不存在。

- [ ] **Step 3: 为新 screen 时清空 `.events` 再写一个失败测试**

再加一个测试：

```javascript
    // Test: .events cleared on new screen
    console.log('Test: .events cleared on new screen');
    // .events file should still exist from previous test
    assert(fs.existsSync(path.join(TEST_DIR, '.events')), '.events should exist before new screen');
    fs.writeFileSync(path.join(TEST_DIR, 'new-screen.html'), '<h2>New screen</h2>');
    await sleep(500);
    assert(!fs.existsSync(path.join(TEST_DIR, '.events')), '.events should be cleared after new screen');
    console.log('  PASS');
```

- [ ] **Step 4: 运行测试，确认它失败**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：新测试失败，因为 screen 推送后 `.events` 不会被清空。

- [ ] **Step 5: 在 `index.js` 中实现 `.events` 文件写入**

在 WebSocket 的 `message` handler（`index.js` 第 74-77 行）中，`console.log` 之后加入：

```javascript
    // 将用户事件写入 .events 文件，供 Claude 读取
    if (event.choice) {
      const eventsFile = path.join(SCREEN_DIR, '.events');
      fs.appendFileSync(eventsFile, JSON.stringify(event) + '\n');
    }
```

在 chokidar 的 `add` handler（第 104-111 行）中，添加 `.events` 清理逻辑：

```javascript
    if (filePath.endsWith('.html')) {
      // 清除上一屏的事件
      const eventsFile = path.join(SCREEN_DIR, '.events');
      if (fs.existsSync(eventsFile)) fs.unlinkSync(eventsFile);

      console.log(JSON.stringify({ type: 'screen-added', file: filePath }));
      // ... existing reload broadcast
    }
```

- [ ] **Step 6: 用注释占位符替换 `wrapInFrame`**

替换 `wrapInFrame` 函数（`index.js` 第 27-32 行）：

```javascript
function wrapInFrame(content) {
  return frameTemplate.replace('<!-- CONTENT -->', content);
}
```

- [ ] **Step 7: 运行全部测试**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：新的 `.events` 测试通过。已有测试里仍可能存在旧断言失败（在 Task 4 修复）。

- [ ] **Step 8: 提交**

```bash
git add lib/brainstorm-server/index.js tests/brainstorm-server/server.test.js
git commit -m "Add .events file writing and comment-based content injection to brainstorm server"
```

---

### Task 3：简化 `helper.js`

**Files:**
- Modify: `lib/brainstorm-server/helper.js`

- [ ] **Step 1: 移除 `sendToClaude` 函数**

删除 `sendToClaude` 函数（第 92-106 行），包括函数体和页面接管 HTML。

- [ ] **Step 2: 移除 `window.send` 函数**

删除 `window.send` 函数（第 120-129 行），它原本绑定到已经被移除的 Send 按钮。

- [ ] **Step 3: 移除表单提交和输入变化 handler**

删除表单提交 handler（第 57-71 行）和输入变化 handler（第 73-89 行），同时删除 `inputTimeout` 变量。

- [ ] **Step 4: 移除 `pageshow` 事件监听器**

删除之前添加的 `pageshow` listener（现在已经没有 textarea 需要清空）。

- [ ] **Step 5: 将点击 handler 收窄到仅处理 `[data-choice]`**

把点击 handler（第 36-55 行）替换为更窄的版本：

```javascript
  // 捕获 choice 元素上的点击
  document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-choice]');
    if (!target) return;

    sendEvent({
      type: 'click',
      text: target.textContent.trim(),
      choice: target.dataset.choice,
      id: target.id || null
    });
  });
```

- [ ] **Step 6: 在点击 choice 时更新 indicator bar**

在点击 handler 中 `sendEvent` 调用后，添加：

```javascript
    // 更新指示栏
    const indicator = document.getElementById('indicator-text');
    if (indicator) {
      const label = target.querySelector('h3, .content h3, .card-body h3')?.textContent?.trim() || target.dataset.choice;
      indicator.innerHTML = '<span class="selected-text">' + label + ' selected</span> — return to terminal to continue';
    }
```

- [ ] **Step 7: 从 `window.brainstorm` API 中移除 `sendToClaude`**

更新 `window.brainstorm` 对象（第 132-136 行），删除 `sendToClaude`：

```javascript
  window.brainstorm = {
    send: sendEvent,
    choice: (value, metadata = {}) => sendEvent({ type: 'choice', value, ...metadata })
  };
```

- [ ] **Step 8: 运行测试**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```

- [ ] **Step 9: 提交**

```bash
git add lib/brainstorm-server/helper.js
git commit -m "Simplify helper.js: remove feedback functions, narrow to choice capture + indicator"
```

---

### Task 4：为新结构更新测试

**Files:**
- Modify: `tests/brainstorm-server/server.test.js`

**Note:** 下面提到的行号来自_原始_文件。Task 2 已经在文件前面插入了新测试，所以实际行号会发生偏移。请按 `console.log` 标签查找测试（例如 "Test 5:"、"Test 6:"）。

- [ ] **Step 1: 更新 Test 5（完整文档断言）**

找到 Test 5 中的断言 `!fullRes.body.includes('feedback-footer')`。把它改成：完整文档也**不应该**拥有 indicator bar（因为它们应按原样返回）：

```javascript
    assert(!fullRes.body.includes('indicator-bar') || fullDoc.includes('indicator-bar'),
      'Should not wrap full documents in frame template');
```

- [ ] **Step 2: 更新 Test 6（片段包装）**

第 125 行：用 indicator bar 断言替换 `feedback-footer` 断言：

```javascript
    assert(fragRes.body.includes('indicator-bar'), 'Fragment should get indicator bar from frame');
```

同时验证内容占位符已被替换（片段内容出现，注释占位符不应再出现）：

```javascript
    assert(!fragRes.body.includes('<!-- CONTENT -->'), 'Content placeholder should be replaced');
```

- [ ] **Step 3: 更新 Test 7（helper.js API）**

第 140-142 行：更新断言以匹配新的 API 面：

```javascript
    assert(helperContent.includes('toggleSelect'), 'helper.js should define toggleSelect');
    assert(helperContent.includes('sendEvent'), 'helper.js should define sendEvent');
    assert(helperContent.includes('selectedChoice'), 'helper.js should track selectedChoice');
    assert(helperContent.includes('brainstorm'), 'helper.js should expose brainstorm API');
    assert(!helperContent.includes('sendToClaude'), 'helper.js should not contain sendToClaude');
```

- [ ] **Step 4: 用 indicator bar 测试替换 Test 8（sendToClaude 主题支持）**

替换 Test 8（第 145-149 行），因为 `sendToClaude` 已不存在。改为测试 indicator bar：

```javascript
    // Test 8: Indicator bar uses CSS variables (theme support)
    console.log('Test 8: Indicator bar uses CSS variables');
    const templateContent = fs.readFileSync(
      path.join(__dirname, '../../lib/brainstorm-server/frame-template.html'), 'utf-8'
    );
    assert(templateContent.includes('indicator-bar'), 'Template should have indicator bar');
    assert(templateContent.includes('indicator-text'), 'Template should have indicator text element');
    console.log('  PASS');
```

- [ ] **Step 5: 运行完整测试套件**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：**全部**测试通过。

- [ ] **Step 6: 提交**

```bash
git add tests/brainstorm-server/server.test.js
git commit -m "Update brainstorm server tests for new template structure and helper.js API"
```

---

### Task 5：删除 `wait-for-feedback.sh`

**Files:**
- Delete: `lib/brainstorm-server/wait-for-feedback.sh`

- [ ] **Step 1: 确认没有其他文件导入或引用 `wait-for-feedback.sh`**

搜索整个代码库：
```bash
grep -r "wait-for-feedback" /Users/drewritter/prime-rad/superpowers/ --include="*.js" --include="*.md" --include="*.sh" --include="*.json"
```

预期引用：只有 `visual-companion.md`（Task 6 中会重写），以及可能存在的 release notes（属于历史记录，可保留）。

- [ ] **Step 2: 删除文件**

```bash
rm lib/brainstorm-server/wait-for-feedback.sh
```

- [ ] **Step 3: 运行测试，确认没有破坏**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：所有测试通过（没有测试引用这个文件）。

- [ ] **Step 4: 提交**

```bash
git add -u lib/brainstorm-server/wait-for-feedback.sh
git commit -m "Delete wait-for-feedback.sh: replaced by .events file"
```

---

### Task 6：重写 `visual-companion.md`

**Files:**
- Modify: `skills/brainstorming/visual-companion.md`

- [ ] **Step 1: 更新 “How It Works” 描述（第 18 行）**

把“以 JSON 形式接收反馈”的那句话替换为：

```markdown
The server watches a directory for HTML files and serves the newest one to the browser. You write HTML content, the user sees it in their browser and can click to select options. Selections are recorded to a `.events` file that you read on your next turn.
```

- [ ] **Step 2: 更新片段描述（第 20 行）**

把 frame template 描述中的 “feedback footer” 去掉：

```markdown
**Content fragments vs full documents:** If your HTML file starts with `<!DOCTYPE` or `<html`, the server serves it as-is (just injects the helper script). Otherwise, the server automatically wraps your content in the frame template — adding the header, CSS theme, selection indicator, and all interactive infrastructure. **Write content fragments by default.** Only write full documents when you need complete control over the page.
```

- [ ] **Step 3: 重写 “The Loop” 一节（第 36-61 行）**

用下面内容替换整个 “The Loop” 部分：

```markdown
## The Loop

1. **Write HTML** to a new file in `screen_dir`:
   - Use semantic filenames: `platform.html`, `visual-style.html`, `layout.html`
   - **Never reuse filenames** — each screen gets a fresh file
   - Use Write tool — **never use cat/heredoc** (dumps noise into terminal)
   - Server automatically serves the newest file

2. **Tell user what to expect and end your turn:**
   - Remind them of the URL (every step, not just first)
   - Give a brief text summary of what's on screen (e.g., "Showing 3 layout options for the homepage")
   - Ask them to respond in the terminal: "Take a look and let me know what you think. Click to select an option if you'd like."

3. **On your next turn** — after the user responds in the terminal:
   - Read `$SCREEN_DIR/.events` if it exists — this contains the user's browser interactions (clicks, selections) as JSON lines
   - Merge with the user's terminal text to get the full picture
   - The terminal message is the primary feedback; `.events` provides structured interaction data

4. **Iterate or advance** — if feedback changes current screen, write a new file (e.g., `layout-v2.html`). Only move to the next question when the current step is validated.

5. Repeat until done.
```

- [ ] **Step 4: 替换 “User Feedback Format” 一节（第 165-174 行）**

替换为：

```markdown
## Browser Events Format

When the user clicks options in the browser, their interactions are recorded to `$SCREEN_DIR/.events` (one JSON object per line). The file is cleared automatically when you push a new screen.

```jsonl
{"type":"click","choice":"a","text":"Option A - Simple Layout","timestamp":1706000101}
{"type":"click","choice":"c","text":"Option C - Complex Grid","timestamp":1706000108}
{"type":"click","choice":"b","text":"Option B - Hybrid","timestamp":1706000115}
```

The full event stream shows the user's exploration path — they may click multiple options before settling. The last `choice` event is typically the final selection, but the pattern of clicks can reveal hesitation or preferences worth asking about.

If `.events` doesn't exist, the user didn't interact with the browser — use only their terminal text.
```

- [ ] **Step 5: 更新 “Writing Content Fragments” 描述（第 65 行）**

删除 “feedback footer” 引用：

```markdown
Write just the content that goes inside the page. The server wraps it in the frame template automatically (header, theme CSS, selection indicator, and all interactive infrastructure).
```

- [ ] **Step 6: 更新 Reference 一节（第 200-203 行）**

删除关于 helper.js “JS API” 的说明，保留路径引用：

```markdown
## Reference

- Frame template (CSS reference): `${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/frame-template.html`
- Helper script (client-side): `${CLAUDE_PLUGIN_ROOT}/lib/brainstorm-server/helper.js`
```

- [ ] **Step 7: 提交**

```bash
git add skills/brainstorming/visual-companion.md
git commit -m "Rewrite visual-companion.md for non-blocking browser-displays-terminal-commands flow"
```

---

### Task 7：最终验证

- [ ] **Step 1: 运行完整测试套件**

```bash
cd /Users/drewritter/prime-rad/superpowers && node tests/brainstorm-server/server.test.js
```
预期：**全部**测试通过。

- [ ] **Step 2: 手工 smoke test**

手动启动服务端，验证端到端流程正常：

```bash
cd /Users/drewritter/prime-rad/superpowers && lib/brainstorm-server/start-server.sh --project-dir /tmp/brainstorm-smoke-test
```

写一个测试片段，打开浏览器，点击某个选项，验证 `.events` 文件已写入，验证 indicator bar 会更新。然后停止服务端：

```bash
lib/brainstorm-server/stop-server.sh <screen_dir from start output>
```

- [ ] **Step 3: 验证没有残留旧引用**

```bash
grep -r "wait-for-feedback\|sendToClaude\|feedback-footer\|send-to-claude\|TaskOutput.*block.*true" /Users/drewritter/prime-rad/superpowers/ --include="*.js" --include="*.md" --include="*.sh" --include="*.html" | grep -v node_modules | grep -v RELEASE-NOTES | grep -v "\.md:.*spec\|plan"
```

预期：除 release notes 和这些 spec/plan 文档（属于历史记录）外，没有任何命中。

- [ ] **Step 4: 如有必要，做最终清理提交**

```bash
git status
# 检查未跟踪/已修改文件，按需精确暂存，若工作区干净则提交
```
