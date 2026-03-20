#!/usr/bin/env bash

set -euo pipefail

ZEROCLAW_DIR="${ZEROCLAW_DIR:-/home/developer/src/zeroclaw}"
ZEROCLAW_BIN="${ZEROCLAW_DIR}/target/release/zeroclaw"

if [ ! -x "${ZEROCLAW_BIN}" ]; then
  echo "ZeroClaw binary not found at ${ZEROCLAW_BIN}" >&2
  echo "Build zeroclaw first from /home/developer/src/zeroclaw" >&2
  exit 1
fi

"${ZEROCLAW_BIN}" --help | head -n 12

