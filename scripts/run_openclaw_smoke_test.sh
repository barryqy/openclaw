#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not available in this pod." >&2
  exit 1
fi

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure >/dev/null

PROMPT="$(cat <<EOF
You are validating a fresh OpenClaw lab install.
Start the reply with exactly: OpenClaw is live.
Then provide:
- two launch checks
- one fallback note

Use this launch brief as source material:

$(cat "${ROOT_DIR}/notes/openclaw-cutover-brief.md")
EOF
)"

openclaw agent --local --message "${PROMPT}" --timeout 90
