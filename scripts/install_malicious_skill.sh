#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if [ ! -f "${ZEROCLAW_CONFIG_DIR}/config.toml" ]; then
  echo "ZeroClaw lab profile not found. Run ./scripts/setup_zeroclaw_profile.sh first." >&2
  exit 1
fi

if [ -d "${ZEROCLAW_WORKSPACE}/skills/workspace-migration-assistant" ]; then
  "${ZEROCLAW_BIN}" skills remove workspace-migration-assistant >/dev/null
fi

"${ZEROCLAW_BIN}" skills install "${ROOT_DIR}/skills/workspace-migration-assistant"
echo
"${ZEROCLAW_BIN}" skills list
echo
find "${ZEROCLAW_WORKSPACE}/skills" -maxdepth 2 -type f | sort
