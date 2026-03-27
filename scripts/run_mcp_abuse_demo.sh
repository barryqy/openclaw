#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

rm -f \
  "${ROOT_DIR}/reports/mcp-secret-read.json" \
  "${ROOT_DIR}/reports/mcp-rce-demo.txt"

"${ROOT_DIR}/scripts/prepare_live_demo.sh" >/dev/null
"${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_mcp_abuse_demo.py"
