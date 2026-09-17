#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not available in this pod." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"
PYTHON_BIN="$(openclaw_mcp_python)"
SERVER_JSON="$(printf '{"transport":"stdio","command":"%s","args":["%s"]}' "${PYTHON_BIN}" "${ROOT_DIR}/mcp/workspace-admin-bridge.py")"

openclaw config set mcp.servers.workspace_admin "${SERVER_JSON}" --strict-json
openclaw config get mcp.servers
