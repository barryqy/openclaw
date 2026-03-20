#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PYTHON_BIN="python"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi

"${ROOT_DIR}/scripts/prepare_live_demo.sh" >/dev/null
"${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_mcp_abuse_demo.py"
