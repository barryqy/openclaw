#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

DC_VENV_DIR="${DEFENSECLAW_DIR}/.venv"
DC_PYTHON="${DC_VENV_DIR}/bin/python"
DC_CLI="${DC_VENV_DIR}/bin/defenseclaw"
DC_CFG_PATH="${HOME}/.defenseclaw/config.yaml"
DC_GUARDRAIL_SRC="${DEFENSECLAW_DIR}/internal/gateway/guardrail.go"
OPENCLAW_GATEWAY_URL="http://${OPENCLAW_GATEWAY_HOST}:${OPENCLAW_GATEWAY_PORT}/health"

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
model = str(guardrail.get("model", "") or "").strip()
model_name = str(guardrail.get("model_name", "") or "").strip()
api_base = str(guardrail.get("api_base", "") or "").strip()

raise SystemExit(0 if enabled and model and model_name and api_base else 1)
PY
}

print_defenseclaw_summary() {
  "${DC_PYTHON}" - "${DEFENSECLAW_DIR}" "${DC_CFG_PATH}" "${DC_GUARDRAIL_SRC}" <<'PY'
from pathlib import Path
import sys

import yaml

repo_dir = Path(sys.argv[1])
cfg_path = Path(sys.argv[2])
guardrail_src = Path(sys.argv[3])

print(f"DEFENSECLAW_DIR={repo_dir}")
print(f"DEFENSECLAW_VENV={repo_dir / '.venv'}")
print(f"DEFENSECLAW_CLI={repo_dir / '.venv' / 'bin' / 'defenseclaw'}")

if cfg_path.exists():
    cfg = yaml.safe_load(cfg_path.read_text(encoding='utf-8')) or {}
    guardrail = cfg.get("guardrail", {}) or {}
    enabled = bool(guardrail.get("enabled", False))
    model = str(guardrail.get("model", "") or "").strip()
    model_name = str(guardrail.get("model_name", "") or "").strip()
    api_base = str(guardrail.get("api_base", "") or "").strip()
    configured = enabled and model and model_name and api_base

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

privacy_rule_enabled = False
if guardrail_src.exists():
    privacy_rule_enabled = "privacy-exfil-request" in guardrail_src.read_text(encoding="utf-8")

print(f"LAB_PRIVACY_RULE={'enabled' if privacy_rule_enabled else 'missing'}")
PY
}

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
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

print_defenseclaw_summary

if wait_for_http_ok "${OPENCLAW_GATEWAY_URL}" 20; then
  echo "OPENCLAW_GATEWAY=healthy"
else
  echo "OPENCLAW_GATEWAY=unreachable" >&2
  echo "Run ./scripts/manage_openclaw_gateway.sh ensure if OpenClaw is down." >&2
  exit 1
fi

if ! guardrail_is_configured; then
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
