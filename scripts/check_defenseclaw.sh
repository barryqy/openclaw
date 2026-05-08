#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

DC_VENV_DIR="${DEFENSECLAW_DIR}/.venv"
DC_PYTHON="${DC_VENV_DIR}/bin/python"
DC_CLI="${DC_VENV_DIR}/bin/defenseclaw"
DC_CFG_PATH="${HOME}/.defenseclaw/config.yaml"
DC_MARKER_PATH="${DEFENSECLAW_CONFIGURED_MARKER_FILE}"
DC_POLICY_DATA_PATH="${HOME}/.defenseclaw/policies/rego/data.json"
OPENCLAW_GATEWAY_URL="http://${OPENCLAW_GATEWAY_HOST}:${OPENCLAW_GATEWAY_PORT}/health"
OPENCLAW_PLUGIN_DIR="${OPENCLAW_DEFENSECLAW_PLUGIN_DIR}"
OPENCLAW_PLUGIN_ENTRY="${OPENCLAW_PLUGIN_DIR}/dist/index.js"

check_python_module() {
  local module_name="$1"

  "${DC_PYTHON}" - "${module_name}" <<'PY' >/dev/null 2>&1
import importlib.util
import sys

raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
}

http_ok() {
  local url="$1"

  python3 - "${url}" <<'PY'
import sys
import urllib.request

url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=2) as resp:
        raise SystemExit(0 if resp.status == 200 else 1)
except Exception:
    raise SystemExit(1)
PY
}

wait_for_http_ok() {
  local url="$1"
  local attempts="${2:-1}"
  local idx=0

  while [ "${idx}" -lt "${attempts}" ]; do
    if http_ok "${url}"; then
      return 0
    fi
    idx=$((idx + 1))
    sleep 1
  done

  return 1
}

read_guardrail_port() {
  "${DC_PYTHON}" - "${DC_CFG_PATH}" <<'PY'
from pathlib import Path
import sys

import yaml

cfg_path = Path(sys.argv[1])
cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
guardrail = cfg.get("guardrail", {}) or {}
print(int(guardrail.get("port", 4000) or 4000))
PY
}

guardrail_is_configured() {
  if [ ! -f "${DC_CFG_PATH}" ]; then
    return 1
  fi

  "${DC_PYTHON}" - "${DC_CFG_PATH}" <<'PY' >/dev/null 2>&1
from pathlib import Path
import sys

import yaml

cfg_path = Path(sys.argv[1])
cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
guardrail = cfg.get("guardrail", {}) or {}

enabled = bool(guardrail.get("enabled", False))
guardrail_llm = guardrail.get("llm", {}) or {}
model = str(guardrail_llm.get("model", "") or guardrail.get("model", "") or "").strip()
model_name = str(guardrail.get("model_name", "") or "").strip()
api_base = str(guardrail_llm.get("base_url", "") or guardrail.get("api_base", "") or "").strip()

raise SystemExit(0 if enabled and model and model_name and api_base else 1)
PY
}

lab_guardrail_is_configured() {
  [ -f "${DC_MARKER_PATH}" ] || return 1
  guardrail_is_configured
}

print_defenseclaw_summary() {
  "${DC_PYTHON}" - "${DEFENSECLAW_DIR}" "${DC_CFG_PATH}" "${DC_MARKER_PATH}" "${DC_POLICY_DATA_PATH}" <<'PY'
import importlib.metadata
import json
from pathlib import Path
import sys

import yaml

install_dir = Path(sys.argv[1])
cfg_path = Path(sys.argv[2])
marker_path = Path(sys.argv[3])
policy_data_path = Path(sys.argv[4])

try:
    version = importlib.metadata.version("defenseclaw")
except importlib.metadata.PackageNotFoundError:
    version = "unknown"

print(f"DEFENSECLAW_VERSION={version}")
print(f"DEFENSECLAW_DIR={install_dir}")
print(f"DEFENSECLAW_VENV={install_dir / '.venv'}")
print(f"DEFENSECLAW_CLI={install_dir / '.venv' / 'bin' / 'defenseclaw'}")

if policy_data_path.exists():
    try:
        policy_data = json.loads(policy_data_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        policy_data = {}
    policy_cfg = policy_data.get("config", {}) or {}
    policy_name = str(
        policy_data.get("policy_name", "") or policy_cfg.get("policy_name", "") or ""
    ).strip()
    guardrail_data = policy_data.get("guardrail", {}) or {}
    if policy_name:
        print(f"POLICY={policy_name}")
    if guardrail_data:
        print(f"GUARDRAIL_BLOCK_THRESHOLD={guardrail_data.get('block_threshold', '')}")
        print(f"GUARDRAIL_ALERT_THRESHOLD={guardrail_data.get('alert_threshold', '')}")

if cfg_path.exists():
    cfg = yaml.safe_load(cfg_path.read_text(encoding='utf-8')) or {}
    guardrail = cfg.get("guardrail", {}) or {}
    guardrail_llm = guardrail.get("llm", {}) or {}
    enabled = bool(guardrail.get("enabled", False))
    model = str(guardrail_llm.get("model", "") or guardrail.get("model", "") or "").strip()
    model_name = str(guardrail.get("model_name", "") or "").strip()
    api_base = str(guardrail_llm.get("base_url", "") or guardrail.get("api_base", "") or "").strip()
    configured = marker_path.exists() and enabled and model and model_name and api_base

    if configured:
        print("GUARDRAIL_STATUS=configured")
        print("GUARDRAIL_ENABLED=true")
        print(f"GUARDRAIL_MODE={guardrail.get('mode', '')}")
        print(f"GUARDRAIL_SCANNER_MODE={guardrail.get('scanner_mode', '')}")
        print(f"GUARDRAIL_MODEL={model}")
        print(f"GUARDRAIL_MODEL_NAME={model_name}")
        print(f"GUARDRAIL_API_BASE={api_base}")
    else:
        print("GUARDRAIL_STATUS=not-configured-yet")
        print("NEXT_STEP=./scripts/configure_defenseclaw.sh")
else:
    print("GUARDRAIL_STATUS=not-configured-yet")
    print("NEXT_STEP=./scripts/configure_defenseclaw.sh")
PY
}

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw install directory not found at ${DEFENSECLAW_DIR}." >&2
  echo "Run ./scripts/install_defenseclaw.sh first." >&2
  exit 1
fi

if [ ! -x "${DC_PYTHON}" ] || [ ! -x "${DC_CLI}" ]; then
  echo "DefenseClaw is not installed in ${DEFENSECLAW_DIR} yet." >&2
  echo "Run ./scripts/install_defenseclaw.sh first." >&2
  exit 1
fi

if ! command -v defenseclaw-gateway >/dev/null 2>&1; then
  echo "DefenseClaw gateway is not on PATH yet." >&2
  echo "Run ./scripts/install_defenseclaw.sh again and let it finish cleanly." >&2
  exit 1
fi

echo "DEFENSECLAW_GATEWAY=$(command -v defenseclaw-gateway)"
echo "OPENCLAW_GATEWAY_URL=${OPENCLAW_GATEWAY_URL}"

if check_python_module "skill_scanner"; then
  echo "SKILL_SCANNER=ready"
else
  echo "SKILL_SCANNER=missing" >&2
  echo "Run ./scripts/install_defenseclaw.sh again to reinstall the scanner packages." >&2
  exit 1
fi

if check_python_module "mcpscanner"; then
  echo "MCP_SCANNER=ready"
else
  echo "MCP_SCANNER=missing" >&2
  echo "Run ./scripts/install_defenseclaw.sh again to reinstall the scanner packages." >&2
  exit 1
fi

echo "OPENCLAW_PLUGIN_DIR=${OPENCLAW_PLUGIN_DIR}"
if [ -f "${OPENCLAW_PLUGIN_ENTRY}" ] && [ -f "${OPENCLAW_PLUGIN_DIR}/package.json" ]; then
  echo "OPENCLAW_PLUGIN=ready"
else
  echo "OPENCLAW_PLUGIN=missing" >&2
  echo "Run ./scripts/install_defenseclaw.sh again to restage the DefenseClaw plugin into OpenClaw." >&2
  exit 1
fi

print_defenseclaw_summary

if wait_for_http_ok "${OPENCLAW_GATEWAY_URL}" 20; then
  echo "OPENCLAW_GATEWAY=healthy"
else
  echo "OPENCLAW_GATEWAY=unreachable" >&2
  echo "Run ./scripts/manage_openclaw_gateway.sh ensure if OpenClaw is down." >&2
  exit 1
fi

if ! lab_guardrail_is_configured; then
  exit 0
fi

guardrail_port="$(read_guardrail_port)"
guardrail_url="http://127.0.0.1:${guardrail_port}/health/liveliness"
echo "GUARDRAIL_HEALTH_URL=${guardrail_url}"

if wait_for_http_ok "${guardrail_url}" 20; then
  echo "GUARDRAIL_HEALTH=healthy"
else
  echo "GUARDRAIL_HEALTH=unreachable" >&2
  echo "Run ./scripts/configure_defenseclaw.sh or restart defenseclaw-gateway." >&2
  exit 1
fi
