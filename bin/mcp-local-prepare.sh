#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_VENV="$PROJECT_ROOT/.venv"
PYTHON_BIN=""
VENV_PYTHON="$MCP_VENV/bin/python"
RECREATE_VENV="0"
SDK_URL="git+https://github.com/dairoot/mcp-calculator"

if [[ -x "$VENV_PYTHON" ]]; then
  venv_ver="$("$VENV_PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  venv_major="${venv_ver%%.*}"
  venv_minor="${venv_ver##*.}"
  if [[ "$venv_major" -gt 3 || ( "$venv_major" -eq 3 && "$venv_minor" -ge 10 ) ]]; then
    source "$MCP_VENV/bin/activate"
    python -m pip install --upgrade pip >/dev/null
    pip install "$SDK_URL" >/dev/null
    echo "MCP runtime ready: $MCP_VENV (python: existing $venv_ver)"
    exit 0
  fi
  RECREATE_VENV="1"
fi

for candidate in python3.12 python3.11 python3.10 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    ver="$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    major="${ver%%.*}"
    minor="${ver##*.}"
    if [[ "$major" -gt 3 || ( "$major" -eq 3 && "$minor" -ge 10 ) ]]; then
      PYTHON_BIN="$candidate"
      break
    fi
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  echo "Python >= 3.10 is required for mcp dependencies."
  echo "Please install Python 3.10+ (for example: brew install python@3.11), then rerun."
  exit 1
fi

if [[ "$RECREATE_VENV" == "1" ]]; then
  rm -rf "$MCP_VENV"
fi

if [[ ! -x "$VENV_PYTHON" ]]; then
  "$PYTHON_BIN" -m venv "$MCP_VENV"
fi

source "$MCP_VENV/bin/activate"
python -m pip install --upgrade pip >/dev/null
pip install "$SDK_URL" >/dev/null

echo "MCP runtime ready: $MCP_VENV (python: $PYTHON_BIN)"
