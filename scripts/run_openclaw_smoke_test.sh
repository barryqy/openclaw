#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "${ROOT_DIR}/scripts/ensure_openclaw_ready.sh"

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

openclaw agent --local --agent main --message "${PROMPT}" --timeout 90
