#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="$PROJECT_ROOT/vendor/mcp-project"
MCP_VENV="$MCP_DIR/.venv"
MCP_CONFIG="$MCP_DIR/mcp_config.json"
BRIDGE_DIR="$MCP_DIR/.bridge"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash bin/mcp-local-enable.sh <MCP_ENDPOINT> [script_file]"
  exit 1
fi

MCP_ENDPOINT="$1"
SCRIPT_FILE="${2:-$MCP_DIR/calculator.py}"

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Script file not found: $SCRIPT_FILE"
  exit 1
fi

bash "$PROJECT_ROOT/bin/mcp-local-prepare.sh" >/dev/null

source "$MCP_VENV/bin/activate"

SCRIPT_FILE="$(python -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$SCRIPT_FILE")"
PYTHON_BIN="$MCP_VENV/bin/python"

mkdir -p "$BRIDGE_DIR"
ENDPOINT_KEY="$(printf '%s' "$MCP_ENDPOINT" | shasum -a 256 | awk '{print $1}')"
PID_FILE="$BRIDGE_DIR/$ENDPOINT_KEY.pid"
LOG_FILE="$BRIDGE_DIR/$ENDPOINT_KEY.log"

# Register script into config so all services run in one bridge process.
"$PYTHON_BIN" - "$MCP_CONFIG" "$SCRIPT_FILE" "$PYTHON_BIN" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
script_path = Path(sys.argv[2]).resolve()
py_bin = sys.argv[3]
name_base = re.sub(r"[^a-z0-9_]+", "-", script_path.stem.lower()).strip("-") or "service"
service_name = f"local-stdio-{name_base}"

if cfg_path.exists():
    data = json.loads(cfg_path.read_text(encoding="utf-8"))
else:
    data = {}
servers = data.setdefault("mcpServers", {})
servers[service_name] = {
    "type": "stdio",
    "command": py_bin,
    "args": [str(script_path)],
}
cfg_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(service_name)
PY

restart_bridge() {
  if [[ -f "$PID_FILE" ]]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
      echo "MCP bridge already running with same endpoint. Reusing single ws connection."
      echo "pid=$old_pid, log=$LOG_FILE"
      echo "Service was registered to config and will use the same bridge process."
      return 0
    fi
  fi
  export MCP_ENDPOINT
  nohup "$PYTHON_BIN" "$MCP_DIR/mcp_pipe.py" >"$LOG_FILE" 2>&1 &
  echo "$!" > "$PID_FILE"
}

restart_bridge
echo "MCP bridge started (single process mode). pid=$(cat "$PID_FILE"), log=$LOG_FILE"
