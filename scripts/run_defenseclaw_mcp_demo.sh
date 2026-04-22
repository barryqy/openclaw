#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASE_NAME="${1:-full-replay}"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"
PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"
HOST_PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"

if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

if [ ! -x "${HOST_PYTHON_BIN}" ]; then
  HOST_PYTHON_BIN="/usr/bin/python3"
fi

if [ ! -x "${HOST_PYTHON_BIN}" ]; then
  HOST_PYTHON_BIN="$(command -v python3)"
fi

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  exit 1
fi

sidecar_health() {
  python3 - <<'PY'
from pathlib import Path
import urllib.request

import yaml


cfg_path = Path.home() / ".defenseclaw" / "config.yaml"
api_port = 18970

if cfg_path.exists():
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    gateway_cfg = cfg.get("gateway", {})
    api_port = int(gateway_cfg.get("api_port", api_port))

url = f"http://127.0.0.1:{api_port}/health"
try:
    with urllib.request.urlopen(url, timeout=2) as resp:
        raise SystemExit(0 if resp.status == 200 else 1)
except Exception:
    raise SystemExit(1)
PY
}

ensure_sidecar() {
  if sidecar_health; then
    return 0
  fi

  echo "Starting DefenseClaw sidecar for guarded MCP checks..."
  if command -v defenseclaw-gateway >/dev/null 2>&1; then
    if ! defenseclaw-gateway restart >/tmp/defenseclaw-sidecar.log 2>&1; then
      defenseclaw-gateway start >/tmp/defenseclaw-sidecar.log 2>&1 || true
    fi
  fi

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if sidecar_health; then
      return 0
    fi
    sleep 1
  done

  echo "DefenseClaw sidecar API did not become ready." >&2
  echo "Recent sidecar output:" >&2
  cat /tmp/defenseclaw-sidecar.log >&2 || true
  return 1
}

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

ensure_sidecar

set_safe_reference_with_fallback() {
  local output=""
  local rc=0

  set +e
  output="$(defenseclaw mcp set safe_reference \
    --command "${HOST_PYTHON_BIN}" \
    --args "[\"${ROOT_DIR}/mcp/safe-migration-reference-server.py\"]" \
    --transport stdio 2>&1)"
  rc=$?
  set -e

  if [ -n "${output}" ]; then
    printf '%s\n' "${output}"
  fi

  if [ "${rc}" -eq 0 ]; then
    return 0
  fi

  if printf '%s' "${output}" | grep -Eq 'Status:[[:space:]]+CLEAN' &&
     printf '%s' "${output}" | grep -Eq 'TimeoutExpired|timed out after [0-9]+ seconds'; then
    echo "DefenseClaw scan passed, but the OpenClaw config write timed out. Applying the lab MCP fallback..."
    bash "${ROOT_DIR}/scripts/add_safe_mcp.sh"
    return 0
  fi

  if printf '%s' "${output}" | grep -Eq 'fastmcp is required|Unable to connect to stdio MCP server|Connection closed'; then
    echo "DefenseClaw safe MCP scan failed with the host Python. Applying the lab MCP fallback..."
    bash "${ROOT_DIR}/scripts/add_safe_mcp.sh"
    return 0
  fi

  return "${rc}"
}

set_safe_reference_with_fallback

set +e
malicious_output="$(defenseclaw mcp set workspace_admin \
  --command "${HOST_PYTHON_BIN}" \
  --args "[\"${ROOT_DIR}/mcp/workspace-admin-bridge.py\"]" \
  --transport stdio 2>&1)"
malicious_rc=$?
set -e

printf '%s\n' "${malicious_output}" > "${ROOT_DIR}/reports/defenseclaw-malicious-mcp.txt"

if [ "${malicious_rc}" -eq 0 ]; then
  echo "DefenseClaw allowed the 🚨 malicious MCP server." >&2
  exit 1
fi

echo "Rejected 🚨 malicious MCP server: workspace_admin"
echo "Saved rejection details to ${ROOT_DIR}/reports/defenseclaw-malicious-mcp.txt"
if [ -n "${malicious_output}" ]; then
  printf '%s\n' "${malicious_output}"
fi

defenseclaw tool block read_runtime_config --reason "lab demo: fake credential harvesting"
defenseclaw tool block score_template_expression --reason "lab demo: arbitrary code execution"
defenseclaw tool block sync_partner_manifest --reason "lab demo: localhost admin fetch"

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_guarded_mcp_demo.py" "${CASE_NAME}"
