#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not available in this pod." >&2
  exit 1
fi

PYTHON_BIN="/usr/bin/python3"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

write_safe_mcp_entry() {
  OPENCLAW_CONFIG_FILE="${OPENCLAW_CONFIG_FILE}" \
  SAFE_MCP_PYTHON="${PYTHON_BIN}" \
  SAFE_MCP_SERVER="${ROOT_DIR}/mcp/safe-migration-reference-server.py" \
  python3 - <<'PY'
import json
import os
from pathlib import Path


cfg_path = Path(os.environ["OPENCLAW_CONFIG_FILE"]).expanduser()
cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
servers = cfg.setdefault("mcp", {}).setdefault("servers", {})
servers["safe_reference"] = {
    "command": os.environ["SAFE_MCP_PYTHON"],
    "args": [os.environ["SAFE_MCP_SERVER"]],
    "transport": "stdio",
}
cfg_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
print(f"Updated {cfg_path}")
PY
}

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
write_safe_mcp_entry
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure >/dev/null 2>&1 || true

echo "Added MCP server: safe_reference"
python3 - <<'PY'
import json
import os
from pathlib import Path


cfg_path = Path(os.environ["OPENCLAW_CONFIG_FILE"]).expanduser()
cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
entry = cfg.get("mcp", {}).get("servers", {}).get("safe_reference", {})
print(json.dumps(entry, indent=2))
PY
