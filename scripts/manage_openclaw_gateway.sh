#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

gateway_url="http://${OPENCLAW_GATEWAY_HOST}:${OPENCLAW_GATEWAY_PORT}/health"

is_pid_alive() {
  local pid="$1"
  if [ -z "${pid}" ]; then
    return 1
  fi

  kill -0 "${pid}" >/dev/null 2>&1
}

read_pid() {
  if [ ! -f "${OPENCLAW_GATEWAY_PID_FILE}" ]; then
    return 1
  fi

  tr -d '[:space:]' < "${OPENCLAW_GATEWAY_PID_FILE}"
}

gateway_healthy() {
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
  local attempts="${1:-20}"
  local idx=0

  while [ "${idx}" -lt "${attempts}" ]; do
    if gateway_healthy; then
      return 0
    fi
    idx=$((idx + 1))
    sleep 1
  done

  return 1
}

start_gateway() {
  local pid

  mkdir -p "${OPENCLAW_STATE_DIR}"

  if pid="$(read_pid 2>/dev/null)" && is_pid_alive "${pid}"; then
    if gateway_healthy; then
      echo "OpenClaw gateway already running (PID ${pid})"
      echo "Health URL: ${gateway_url}"
      return 0
    fi
  fi

  rm -f "${OPENCLAW_GATEWAY_PID_FILE}"

  echo "Starting OpenClaw gateway in the lab session..."
  nohup env \
    PATH="${PATH}" \
    HOME="${HOME}" \
    OPENCLAW_HOME="${OPENCLAW_HOME}" \
    OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR}" \
    OPENCLAW_CONFIG_FILE="${OPENCLAW_CONFIG_FILE}" \
    OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE}" \
    OPENCLAW_LLM_MODEL="${OPENCLAW_LLM_MODEL}" \
    LLM_BASE_URL="${LLM_BASE_URL:-}" \
    LLM_API_KEY="${LLM_API_KEY:-}" \
    LLM_MODEL="${LLM_MODEL:-}" \
    openclaw gateway run --force >"${OPENCLAW_GATEWAY_LOG_FILE}" 2>&1 &
  pid=$!

  echo "${pid}" > "${OPENCLAW_GATEWAY_PID_FILE}"

  if wait_for_gateway 30; then
    echo "OpenClaw gateway is live at ${gateway_url}"
    echo "Gateway log: ${OPENCLAW_GATEWAY_LOG_FILE}"
    return 0
  fi

  echo "OpenClaw gateway did not become healthy." >&2
  echo "Gateway log: ${OPENCLAW_GATEWAY_LOG_FILE}" >&2
  tail -n 20 "${OPENCLAW_GATEWAY_LOG_FILE}" >&2 || true
  return 1
}

status_gateway() {
  local pid=""

  if pid="$(read_pid 2>/dev/null)" && is_pid_alive "${pid}"; then
    echo "Gateway PID: ${pid}"
  else
    echo "Gateway PID: not running"
  fi

  if gateway_healthy; then
    echo "Gateway health: healthy"
    echo "Health URL: ${gateway_url}"
  else
    echo "Gateway health: not reachable"
    echo "Health URL: ${gateway_url}"
    return 1
  fi

  echo "Gateway log: ${OPENCLAW_GATEWAY_LOG_FILE}"
}

stop_gateway() {
  local pid=""

  if ! pid="$(read_pid 2>/dev/null)" || ! is_pid_alive "${pid}"; then
    rm -f "${OPENCLAW_GATEWAY_PID_FILE}"
    echo "OpenClaw gateway is not running."
    return 0
  fi

  echo "Stopping OpenClaw gateway (PID ${pid})..."
  kill "${pid}" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5; do
    if ! is_pid_alive "${pid}"; then
      break
    fi
    sleep 1
  done

  if is_pid_alive "${pid}"; then
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi

  rm -f "${OPENCLAW_GATEWAY_PID_FILE}"
  echo "OpenClaw gateway stopped."
}

cmd="${1:-ensure}"
case "${cmd}" in
  ensure|start)
    start_gateway
    ;;
  status)
    status_gateway
    ;;
  stop)
    stop_gateway
    ;;
  *)
    echo "usage: manage_openclaw_gateway.sh [ensure|start|status|stop]" >&2
    exit 1
    ;;
esac
