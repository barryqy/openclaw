#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${ROOT_DIR}/scripts/ensure_openclaw_ready.sh"

PROMPT="$(cat <<'EOF'
You are warming up a freshly installed OpenClaw lab.
Keep the reply short and playful.

Start with exactly: OpenClaw warm-up:
Then provide:
- one one-line joke about AI agents and security
- one one-line confidence boost for the student

Keep it to two short lines after the opener.
EOF
)"

openclaw agent --local --agent main --message "${PROMPT}" --timeout 60
