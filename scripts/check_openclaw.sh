#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

gateway_url="http://${OPENCLAW_GATEWAY_HOST}:${OPENCLAW_GATEWAY_PORT}/health"

gateway_ok() {
  python3 - "${gateway_url}" <<'PY'
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

wait_for_gateway() {
  local tries="${1:-10}"
  local n=0

  while [ "${n}" -lt "${tries}" ]; do
    if gateway_ok; then
      return 0
    fi

    n=$((n + 1))
    sleep 1
  done

  return 1
}

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not installed yet." >&2
  echo "Run ./scripts/install_openclaw.sh first." >&2
  exit 1
fi

if [ ! -f "${OPENCLAW_CONFIG_FILE}" ]; then
  echo "OpenClaw is installed, but the lab config is missing." >&2
  echo "Run ./scripts/install_openclaw.sh first." >&2
  exit 1
fi

echo "OPENCLAW_HOME=${OPENCLAW_HOME}"
echo "OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR}"
echo "OPENCLAW_CONFIG_FILE=${OPENCLAW_CONFIG_FILE}"
echo "OPENCLAW_WORKSPACE=${OPENCLAW_WORKSPACE}"
echo "OPENCLAW_GATEWAY_HOST=${OPENCLAW_GATEWAY_HOST}"
echo "OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}"
echo
openclaw config file
echo

if ! wait_for_gateway 10; then
  bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure
fi

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" status
