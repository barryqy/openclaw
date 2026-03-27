#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

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
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" status || bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure
