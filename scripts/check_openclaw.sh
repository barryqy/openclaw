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

echo "OPENCLAW_HOME=${OPENCLAW_HOME}"
echo "OPENCLAW_CONFIG_FILE=${OPENCLAW_CONFIG_FILE}"
echo "OPENCLAW_WORKSPACE=${OPENCLAW_WORKSPACE}"
echo
openclaw config file
echo
openclaw gateway status
