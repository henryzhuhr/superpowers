# 面向 Claude Code 的跨平台 Polyglot Hooks

Claude Code 插件需要能在 Windows、macOS 和 Linux 上工作的 hooks。本文说明使其成为可能的 polyglot 包装器技巧。

## 问题

Claude Code 会通过系统默认 shell 运行 hook 命令：
- **Windows**：CMD.exe
- **macOS/Linux**：bash 或 sh

这会带来几个挑战：

1. **脚本执行**：Windows CMD 不能直接执行 `.sh` 文件，它会尝试用文本编辑器打开它们
2. **路径格式**：Windows 使用反斜杠（`C:\path`），Unix 使用正斜杠（`/path`）
3. **环境变量**：`$VAR` 语法在 CMD 中无效
4. **PATH 中没有 `bash`**：即使安装了 Git Bash，当 CMD 运行时 `bash` 也不在 PATH 中

## 解决方案：Polyglot `.cmd` 包装器

Polyglot 脚本是一段同时对多种语言都合法的语法。我们的包装器同时对 CMD 和 bash 都合法：

```cmd
: << 'CMDBLOCK'
@echo off
"C:\Program Files\Git\bin\bash.exe" -l -c "\"$(cygpath -u \"$CLAUDE_PLUGIN_ROOT\")/hooks/session-start.sh\""
exit /b
CMDBLOCK

# Unix shell 从这里开始运行
"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
```

### 工作原理

#### 在 Windows（CMD.exe）上

1. `: << 'CMDBLOCK'`：CMD 把 `:` 视为标签（类似 `:label`），并忽略 `<< 'CMDBLOCK'`
2. `@echo off`：关闭命令回显
3. `bash.exe` 命令运行时带有：
   - `-l`（login shell），以获得包含 Unix 工具的正确 PATH
   - `cygpath -u`，将 Windows 路径转换为 Unix 格式（`C:\foo` → `/c/foo`）
4. `exit /b`：退出批处理脚本，使 CMD 在此停止
5. `CMDBLOCK` 之后的所有内容 CMD 都不会执行到

#### 在 Unix（bash/sh）上

1. `: << 'CMDBLOCK'`： `:` 是 no-op，`<< 'CMDBLOCK'` 会开始一个 heredoc
2. 直到 `CMDBLOCK` 为止的内容都会被 heredoc 消费掉（即被忽略）
3. `# Unix shell 从这里开始运行`：注释
4. 脚本直接使用 Unix 路径运行

## 文件结构

```
hooks/
├── hooks.json           # 指向 .cmd 包装器
├── session-start.cmd    # Polyglot 包装器（跨平台入口）
└── session-start.sh     # 实际 hook 逻辑（bash 脚本）
```

### hooks.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.cmd\""
          }
        ]
      }
    ]
  }
}
```

注意：路径必须加引号，因为 `${CLAUDE_PLUGIN_ROOT}` 在 Windows 上可能包含空格（例如 `C:\Program Files\...`）。

## 要求

### Windows
- 必须安装 **Git for Windows**（提供 `bash.exe` 和 `cygpath`）
- 默认安装路径：`C:\Program Files\Git\bin\bash.exe`
- 如果 Git 安装在别处，需要修改包装器

### Unix（macOS/Linux）
- 标准 bash 或 sh shell
- `.cmd` 文件必须有可执行权限（`chmod +x`）

## 编写跨平台 Hook 脚本

你的实际 hook 逻辑应该写在 `.sh` 文件中。为了保证它在 Windows（通过 Git Bash）上可用：

### 建议：
- 尽可能使用纯 bash 内建
- 使用 `$(command)` 而不是反引号
- 为所有变量展开加引号：`"$VAR"`
- 使用 `printf` 或 here-doc 输出

### 避免：
- 使用可能不在 PATH 中的外部命令（sed、awk、grep）
- 如果必须用，它们在 Git Bash 中可用，但要确保 PATH 设置正确（使用 `bash -l`）

### 示例：不依赖 sed/awk 的 JSON 转义

不要这样写：
```bash
escaped=$(echo "$content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
```

应使用纯 bash：
```bash
escape_for_json() {
    local input="$1"
    local output=""
    local i char
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            $'\\') output+='\\' ;;
            '"') output+='\"' ;;
            $'\n') output+='\n' ;;
            $'\r') output+='\r' ;;
            $'\t') output+='\t' ;;
            *) output+="$char" ;;
        esac
    done
    printf '%s' "$output"
}
```

## 可复用的包装器模式

对于带多个 hook 的插件，你可以创建一个通用包装器，把脚本名作为参数传入：

### run-hook.cmd
```cmd
: << 'CMDBLOCK'
@echo off
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_NAME=%~1"
"C:\Program Files\Git\bin\bash.exe" -l -c "cd \"$(cygpath -u \"%SCRIPT_DIR%\")\" && \"./%SCRIPT_NAME%\""
exit /b
CMDBLOCK

# Unix shell 从这里开始运行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
"${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

### 使用可复用包装器的 hooks.json
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" validate-bash.sh"
          }
        ]
      }
    ]
  }
}
```

## 故障排查

### “bash is not recognized”

CMD 找不到 bash。该包装器使用完整路径 `C:\Program Files\Git\bin\bash.exe`。如果 Git 安装在其他位置，请更新这个路径。

### “cygpath: command not found” 或 “dirname: command not found”

Bash 不是以 login shell 方式运行。确保使用了 `-l` 参数。

### 路径中出现奇怪的 `\/`

`${CLAUDE_PLUGIN_ROOT}` 被展开成了一个以反斜杠结尾的 Windows 路径，然后又拼接了 `/hooks/...`。请用 `cygpath` 转换整个路径。

### 脚本被文本编辑器打开而不是执行

`hooks.json` 直接指向了 `.sh` 文件。应该改为指向 `.cmd` 包装器。

### 在终端里能工作，但作为 hook 不行

Claude Code 运行 hook 的方式可能不同。可以通过模拟 hook 环境来测试：
```powershell
$env:CLAUDE_PLUGIN_ROOT = "C:\path\to\plugin"
cmd /c "C:\path\to\plugin\hooks\session-start.cmd"
```

## 相关问题

- [anthropics/claude-code#9758](https://github.com/anthropics/claude-code/issues/9758) - `.sh` 脚本在 Windows 上会被编辑器打开
- [anthropics/claude-code#3417](https://github.com/anthropics/claude-code/issues/3417) - Hooks 在 Windows 上无法工作
- [anthropics/claude-code#6023](https://github.com/anthropics/claude-code/issues/6023) - 找不到 `CLAUDE_PROJECT_DIR`
