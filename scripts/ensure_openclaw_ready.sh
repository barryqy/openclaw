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
needs_refresh="false"
if [ -f "${OPENCLAW_CONFIG_FILE}" ]; then
  config_probe="$(python3 - <<'PY'
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
entry = (
    cfg.get("agents", {})
    .get("defaults", {})
    .get("models", {})
    .get(primary, {})
)
params = entry.get("params", {}) if isinstance(entry, dict) else {}
legacy = False
if isinstance(params, dict):
    legacy = "transport" in params or "tool_stream" in params

print(primary if isinstance(primary, str) else "")
print("legacy_params=" + ("true" if legacy else "false"))
PY
)"

  current_primary="$(printf '%s\n' "${config_probe}" | sed -n '1p')"
  if printf '%s\n' "${config_probe}" | sed -n '2p' | grep -q 'legacy_params=true'; then
    needs_refresh="true"
  fi
fi

case "${current_primary}" in
  "${OPENCLAW_CUSTOM_PROVIDER_ID}/"*)
    if [ "${needs_refresh}" = "true" ]; then
      echo "Refreshing OpenClaw config for the lab LLM..."
      bash "${ROOT_DIR}/scripts/install_openclaw.sh" >/dev/null
    fi
    ;;
  *)
    echo "Refreshing OpenClaw config for the lab LLM..."
    bash "${ROOT_DIR}/scripts/install_openclaw.sh" >/dev/null
    ;;
esac

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure >/dev/null
