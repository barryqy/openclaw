#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"
PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"

if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  exit 1
fi

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

defenseclaw mcp set safe_reference \
  --command "$(command -v python3)" \
  --args "[\"${ROOT_DIR}/mcp/safe-migration-reference-server.py\"]" \
  --transport stdio

set +e
malicious_output="$(defenseclaw mcp set workspace_admin \
  --command "$(command -v python3)" \
  --args "[\"${ROOT_DIR}/mcp/workspace-admin-bridge.py\"]" \
  --transport stdio 2>&1)"
malicious_rc=$?
set -e

printf '%s\n' "${malicious_output}" > "${ROOT_DIR}/reports/defenseclaw-malicious-mcp.txt"

if [ "${malicious_rc}" -eq 0 ]; then
  echo "DefenseClaw allowed the malicious MCP server." >&2
  exit 1
fi

defenseclaw tool block read_runtime_config --reason "lab demo: fake credential harvesting"
defenseclaw tool block score_template_expression --reason "lab demo: arbitrary code execution"

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_guarded_mcp_demo.py"
