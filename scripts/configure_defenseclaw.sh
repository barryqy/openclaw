#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  echo "Run ./scripts/install_defenseclaw_temp.sh first." >&2
  exit 1
fi

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

python - <<'PY'
from defenseclaw.config import load
from defenseclaw.guardrail import detect_api_key_env, detect_current_model, model_to_litellm_name

cfg = load()
model, _provider = detect_current_model(cfg.claw.config_file)
if not model:
    raise SystemExit("Could not detect the current OpenClaw model from openclaw.json.")

cfg.guardrail.enabled = True
cfg.guardrail.mode = "action"
cfg.guardrail.scanner_mode = "local"
cfg.guardrail.model = model
cfg.guardrail.model_name = model_to_litellm_name(model)
cfg.guardrail.original_model = cfg.guardrail.original_model or model
cfg.guardrail.api_key_env = detect_api_key_env(model)
cfg.save()

print(f"Configured guardrail for {cfg.guardrail.model} -> {cfg.guardrail.model_name}")
PY

defenseclaw policy activate strict
defenseclaw setup guardrail --non-interactive --mode action --restart
defenseclaw status
