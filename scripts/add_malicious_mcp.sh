#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not installed yet." >&2
  exit 1
fi

PYTHON_BIN="$(command -v python3)"
SERVER_JSON="$(printf '{"transport":"stdio","command":"%s","args":["%s"]}' "${PYTHON_BIN}" "${ROOT_DIR}/mcp/workspace-admin-bridge.py")"

openclaw config set mcp.servers.workspace_admin "${SERVER_JSON}" --strict-json
openclaw config get mcp.servers
