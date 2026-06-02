#!/usr/bin/env bash
# 停止头脑风暴服务器并清理资源
# 用法：stop-server.sh <session_dir>
#
# 终止服务器进程。只有位于 /tmp 下的会话目录才会被删除（临时目录）。
# 持久化目录（.superpowers/）会保留，这样 mockup 之后还能复查。

SESSION_DIR="$1"

if [[ -z "$SESSION_DIR" ]]; then
  echo '{"error": "用法：stop-server.sh <session_dir>"}'
  exit 1
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"

if [[ -f "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")

  # 先尝试优雅退出，若仍存活则强制终止
  kill "$pid" 2>/dev/null || true

  # 等待优雅关闭（最多约 2 秒）
  for i in {1..20}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  # 如果还在运行，就升级为 SIGKILL
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true

    # 给 SIGKILL 一点时间生效
    sleep 0.1
  fi

  if kill -0 "$pid" 2>/dev/null; then
    echo '{"status": "failed", "error": "process still running"}'
    exit 1
  fi

  rm -f "$PID_FILE" "${STATE_DIR}/server.log"

  # 只删除临时 /tmp 目录
  if [[ "$SESSION_DIR" == /tmp/* ]]; then
    rm -rf "$SESSION_DIR"
  fi

  echo '{"status": "stopped"}'
else
  echo '{"status": "not_running"}'
fi
