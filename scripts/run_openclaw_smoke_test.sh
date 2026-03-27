#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not available in this pod." >&2
  exit 1
fi

openclaw_use_lab_openai_env

current_primary=""
if [ -f "${OPENCLAW_CONFIG_FILE}" ]; then
  current_primary="$(python3 - <<'PY'
import json
import os
from pathlib import Path

config_path = Path(os.environ["OPENCLAW_CONFIG_FILE"]).expanduser()
cfg = json.loads(config_path.read_text(encoding="utf-8"))
primary = (
    cfg.get("agents", {})
    .get("defaults", {})
    .get("model", {})
    .get("primary", "")
)
print(primary if isinstance(primary, str) else "")
PY
)"
fi

case "${current_primary}" in
  "${OPENCLAW_CUSTOM_PROVIDER_ID}/"*)
    ;;
  *)
    echo "Refreshing OpenClaw config for the lab LLM..."
    bash "${ROOT_DIR}/scripts/install_openclaw.sh" >/dev/null
    ;;
esac

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
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

openclaw agent --local --agent main --message "${PROMPT}" --timeout 90
