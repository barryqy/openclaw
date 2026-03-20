#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

openclaw_require_llm

if [ ! -f "${ZEROCLAW_CONFIG_DIR}/config.toml" ]; then
  echo "ZeroClaw lab profile not found. Run ./scripts/setup_zeroclaw_profile.sh first." >&2
  exit 1
fi

if [ ! -f "${ROOT_DIR}/notes/openclaw-cutover-brief.md" ]; then
  echo "Missing cutover brief under ${ROOT_DIR}/notes" >&2
  exit 1
fi

PROMPT="$(cat <<EOF
You are validating a fresh ZeroClaw lab install.
Start the reply with exactly: ZeroClaw agent is live.
Then provide:
- two migration checkpoints
- one rollback note

Use this cutover brief as source material:

$(cat "${ROOT_DIR}/notes/openclaw-cutover-brief.md")
EOF
)"

"${ZEROCLAW_BIN}" status
echo
"${ZEROCLAW_BIN}" agent --temperature 0 -m "${PROMPT}"
