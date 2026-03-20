#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if [ ! -x "${ZEROCLAW_BIN}" ]; then
  echo "ZeroClaw binary not found at ${ZEROCLAW_BIN}" >&2
  echo "Install zeroclaw first with ./install.sh --prebuilt-only --skip-onboard" >&2
  exit 1
fi

echo "ZEROCLAW_BIN=${ZEROCLAW_BIN}"
echo "ZEROCLAW_CONFIG_DIR=${ZEROCLAW_CONFIG_DIR}"
echo
"${ZEROCLAW_BIN}" --help
