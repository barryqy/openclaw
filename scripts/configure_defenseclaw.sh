#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

openclaw_require_llm

if [ -z "${OPENCLAW_LLM_API_BASE:-}" ]; then
  echo "Could not derive the OpenClaw LLM API base from LLM_BASE_URL." >&2
  exit 1
fi

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  echo "Run ./scripts/install_defenseclaw_temp.sh first." >&2
  exit 1
fi

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

export OPENAI_API_KEY="${OPENAI_API_KEY:-${LLM_API_KEY}}"
export OPENAI_API_BASE="${OPENAI_API_BASE:-${OPENCLAW_LLM_API_BASE}}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-${OPENCLAW_LLM_API_BASE}}"

read_guardrail_port() {
  python - <<'PY'
from pathlib import Path

import yaml


cfg_path = Path.home() / ".defenseclaw" / "config.yaml"
if not cfg_path.exists():
    print(4000)
    raise SystemExit(0)

cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
guardrail = cfg.get("guardrail", {}) or {}
print(int(guardrail.get("port", 4000) or 4000))
PY
}

guardrail_healthy() {
  local port="$1"

  python - "${port}" <<'PY'
import sys
import urllib.request

port = sys.argv[1]
url = f"http://127.0.0.1:{port}/health/liveliness"
try:
    with urllib.request.urlopen(url, timeout=2) as resp:
        raise SystemExit(0 if resp.status == 200 else 1)
except Exception:
    raise SystemExit(1)
PY
}

wait_for_guardrail() {
  local port="$1"
  local attempts="${2:-45}"
  local idx=0

  while [ "${idx}" -lt "${attempts}" ]; do
    if guardrail_healthy "${port}"; then
      return 0
    fi
    idx=$((idx + 1))
    sleep 1
  done

  return 1
}

show_guardrail_debug() {
  echo
  echo "DefenseClaw guardrail proxy did not become healthy." >&2
  echo "The sidecar API may be running while the protected LLM path is still down." >&2
  echo >&2
  defenseclaw sidecar status || true
}

python - <<'PY'
from defenseclaw.config import load
from defenseclaw.guardrail import detect_current_model


cfg = load()
current_model, provider = detect_current_model(cfg.claw.config_file)
if not current_model:
    raise SystemExit("Could not detect the current OpenClaw model from openclaw.json.")

if current_model.startswith("litellm/") and cfg.guardrail.original_model:
    current_model = cfg.guardrail.original_model

model_id = current_model.split("/", 1)[1] if "/" in current_model else current_model
guardrail_model = current_model

if provider == "llm-image" or "/" not in current_model:
    # The lab LLM is OpenAI-compatible, so map the custom OpenClaw provider
    # into a LiteLLM upstream that understands api_base.
    guardrail_model = f"openai/{model_id}"

cfg.guardrail.enabled = True
cfg.guardrail.mode = "action"
cfg.guardrail.scanner_mode = "local"
cfg.guardrail.model = guardrail_model
cfg.guardrail.model_name = model_id
cfg.guardrail.original_model = cfg.guardrail.original_model or current_model
cfg.guardrail.api_key_env = "LLM_API_KEY"
cfg.save()

print(
    f"Configured guardrail for {cfg.guardrail.original_model} "
    f"via {cfg.guardrail.model} -> {cfg.guardrail.model_name}"
)
PY

defenseclaw policy activate strict
defenseclaw setup guardrail --non-interactive --mode action --restart

python - <<'PY'
import os
from pathlib import Path

import yaml


def load_env_file(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    if not path.exists():
        return entries

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        entries[key] = value
    return entries


def write_env_file(path: Path, entries: dict[str, str]) -> None:
    lines = [f"{key}={value}" for key, value in sorted(entries.items()) if value]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    path.chmod(0o600)


dc_dir = Path.home() / ".defenseclaw"
cfg_path = dc_dir / "config.yaml"
litellm_path = dc_dir / "litellm_config.yaml"
env_path = dc_dir / ".env"

cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
guardrail_cfg = cfg.get("guardrail", {})
model_name = str(guardrail_cfg.get("model_name", "")).strip()
upstream_model = str(guardrail_cfg.get("model", "")).strip()

litellm_cfg = yaml.safe_load(litellm_path.read_text(encoding="utf-8")) or {}
model_list = litellm_cfg.setdefault("model_list", [])
if not model_list:
    raise SystemExit("LiteLLM config did not contain a model_list entry.")

entry = model_list[0]
entry_model_name = str(entry.get("model_name", "")).strip()
params = entry.setdefault("litellm_params", {})
entry_upstream_model = str(params.get("model", "")).strip()

if not model_name:
    model_name = entry_model_name
if not upstream_model:
    upstream_model = entry_upstream_model

if not model_name or not upstream_model:
    raise SystemExit("DefenseClaw guardrail config is incomplete after setup.")

guardrail_cfg["model_name"] = model_name
guardrail_cfg["model"] = upstream_model
cfg["guardrail"] = guardrail_cfg
cfg_path.write_text(yaml.dump(cfg, default_flow_style=False, sort_keys=False), encoding="utf-8")

entry["model_name"] = model_name
params["model"] = upstream_model
params["api_key"] = "os.environ/LLM_API_KEY"
params["api_base"] = "os.environ/OPENCLAW_LLM_API_BASE"
params["drop_params"] = True

litellm_path.write_text(
    "# Auto-generated by DefenseClaw and patched by the OpenClaw lab.\n\n"
    + yaml.dump(litellm_cfg, default_flow_style=False, sort_keys=False),
    encoding="utf-8",
)

env_entries = load_env_file(env_path)
env_entries["LLM_API_KEY"] = os.environ.get("LLM_API_KEY", "")
env_entries["OPENCLAW_LLM_API_BASE"] = os.environ.get("OPENCLAW_LLM_API_BASE", "")
env_entries["OPENAI_API_KEY"] = os.environ.get("OPENAI_API_KEY", "")
env_entries["OPENAI_API_BASE"] = os.environ.get("OPENAI_API_BASE", "")
env_entries["OPENAI_BASE_URL"] = os.environ.get("OPENAI_BASE_URL", "")
write_env_file(env_path, env_entries)

print(f"Patched {litellm_path} with the lab's custom api_base.")
print(f"Updated {env_path} with the lab LLM credentials.")
PY

if command -v defenseclaw-gateway >/dev/null 2>&1; then
  if ! defenseclaw-gateway restart; then
    defenseclaw-gateway start
  fi
fi

guardrail_port="$(read_guardrail_port)"
guardrail_url="http://127.0.0.1:${guardrail_port}/health/liveliness"

echo "Waiting for DefenseClaw guardrail proxy at ${guardrail_url}..."
if wait_for_guardrail "${guardrail_port}" 45; then
  echo "DefenseClaw guardrail proxy is live at ${guardrail_url}"
else
  show_guardrail_debug
  echo >&2
  echo "Recovery: run /home/developer/src/defenseclaw/.venv/bin/defenseclaw setup guardrail --restart" >&2
  exit 1
fi

bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure
defenseclaw status
echo
defenseclaw sidecar status || true
