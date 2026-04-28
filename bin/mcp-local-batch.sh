#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="$PROJECT_ROOT/vendor/mcp-project"
MCP_VENV="$MCP_DIR/.venv"
BRIDGE_DIR="$MCP_DIR/.bridge"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash bin/mcp-local-batch.sh <MCP_ENDPOINT>"
  exit 1
fi

MCP_ENDPOINT="$1"

bash "$PROJECT_ROOT/bin/mcp-local-prepare.sh" >/dev/null

source "$MCP_VENV/bin/activate"
PYTHON_BIN="$MCP_VENV/bin/python"

mkdir -p "$BRIDGE_DIR"
ENDPOINT_KEY="$(printf '%s' "$MCP_ENDPOINT" | shasum -a 256 | awk '{print $1}')"
PID_FILE="$BRIDGE_DIR/$ENDPOINT_KEY.pid"
LOG_FILE="$BRIDGE_DIR/$ENDPOINT_KEY.log"

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "MCP bridge already running with same endpoint. Reusing single ws connection."
    echo "pid=$old_pid, log=$LOG_FILE"
    exit 0
  fi
fi

export MCP_ENDPOINT
nohup "$PYTHON_BIN" "$MCP_DIR/mcp_pipe.py" >"$LOG_FILE" 2>&1 &
echo "$!" > "$PID_FILE"
echo "MCP bridge started (single process mode). pid=$(cat "$PID_FILE"), log=$LOG_FILE"
