#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

download_file() {
  local url="$1"
  local out_file="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${out_file}"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "${out_file}" "${url}"
    return 0
  fi

  python3 - "${url}" "${out_file}" <<'PY'
import sys
import urllib.request

urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
}

node_runtime_ok() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    return 1
  fi

  local node_ver
  local major
  local minor

  node_ver="$(node --version 2>/dev/null || true)"
  node_ver="${node_ver#v}"

  if [ -z "${node_ver}" ]; then
    return 1
  fi

  IFS=. read -r major minor _ <<<"${node_ver}"

  if [ "${major}" -gt 22 ]; then
    return 0
  fi

  if [ "${major}" -lt 22 ]; then
    return 1
  fi

  [ "${minor}" -ge 14 ]
}

install_node_runtime() {
  local os_name
  local arch
  local os_family
  local platform
  local tmpdir
  local index_json
  local node_ver
  local archive_name
  local install_root
  local extract_dir

  os_name="$(uname -s)"
  arch="$(uname -m)"

  case "${os_name}" in
    Linux)
      os_family="linux"
      ;;
    Darwin)
      os_family="darwin"
      ;;
    *)
      echo "Unsupported operating system for the lab Node bootstrap: ${os_name}" >&2
      return 1
      ;;
  esac

  case "${arch}" in
    x86_64|amd64)
      platform="${os_family}-x64"
      ;;
    aarch64|arm64)
      platform="${os_family}-arm64"
      ;;
    *)
      echo "Unsupported CPU architecture for the lab Node bootstrap: ${arch}" >&2
      return 1
      ;;
  esac

  tmpdir="$(mktemp -d)"
  index_json="${tmpdir}/node-index.json"

  download_file "https://nodejs.org/dist/index.json" "${index_json}"

  node_ver="$(python3 - "${index_json}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    releases = json.load(fh)

for item in releases:
    version = item.get("version", "")
    if version.startswith("v24."):
        print(version)
        break
else:
    raise SystemExit("Unable to find a Node 24 release in index.json")
PY
)"

  archive_name="node-${node_ver}-${platform}.tar.xz"
  install_root="${HOME}/.local/share/openclaw-node/${node_ver}-${platform}"

  if [ ! -x "${install_root}/bin/node" ]; then
    echo "Installing Node ${node_ver} for OpenClaw..."
    download_file "https://nodejs.org/dist/${node_ver}/${archive_name}" "${tmpdir}/${archive_name}"
    mkdir -p "${HOME}/.local/share/openclaw-node" "${HOME}/.local/bin"
    tar -xJf "${tmpdir}/${archive_name}" -C "${tmpdir}"
    extract_dir="${tmpdir}/node-${node_ver}-${platform}"
    rm -rf "${install_root}"
    mv "${extract_dir}" "${install_root}"
  fi

  mkdir -p "${HOME}/.local/bin"
  ln -sf "${install_root}/bin/node" "${HOME}/.local/bin/node"
  ln -sf "${install_root}/bin/npm" "${HOME}/.local/bin/npm"
  ln -sf "${install_root}/bin/npx" "${HOME}/.local/bin/npx"

  export PATH="${HOME}/.local/bin:${PATH}"
  hash -r

  echo "Node ready: $(node --version)"
  echo "npm ready: $(npm --version)"
  rm -rf "${tmpdir}"
}

ensure_node_runtime() {
  if node_runtime_ok; then
    return 0
  fi

  install_node_runtime
}

openclaw_require_llm

ensure_node_runtime

export OPENAI_API_KEY="${OPENAI_API_KEY:-${LLM_API_KEY}}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-${OPENCLAW_LLM_API_BASE}}"

normalize_lab_openclaw_config() {
  python3 - <<'PY'
import json
import os
from pathlib import Path


config_path = Path(os.environ["OPENCLAW_CONFIG_FILE"]).expanduser()
cfg = json.loads(config_path.read_text(encoding="utf-8"))

model_id = os.environ.get("OPENCLAW_LLM_MODEL", "gpt-4o")
provider_id = os.environ.get("OPENCLAW_CUSTOM_PROVIDER_ID", "llm-image")
base_url = os.environ.get("OPENCLAW_LLM_API_BASE", "").strip()
api_key = os.environ.get("LLM_API_KEY", "").strip()
primary_model = f"{provider_id}/{model_id}"

if not base_url:
    raise SystemExit("OPENCLAW_LLM_API_BASE is required to normalize openclaw.json.")

agents = cfg.setdefault("agents", {}).setdefault("defaults", {})
agents.setdefault("model", {})["primary"] = primary_model

models = agents.setdefault("models", {})
entry = models.setdefault(primary_model, {})
params = entry.get("params")
if isinstance(params, dict):
    params.pop("transport", None)
    params.pop("tool_stream", None)
    if not params:
        entry.pop("params", None)

model_defaults = {
    "id": model_id,
    "name": f"{model_id} (Custom Provider)",
    "contextWindow": 16000,
    "maxTokens": 4096,
    "input": ["text"],
    "cost": {
        "input": 0,
        "output": 0,
        "cacheRead": 0,
        "cacheWrite": 0,
    },
    "reasoning": False,
}

models_cfg = cfg.setdefault("models", {})
models_cfg["mode"] = models_cfg.get("mode") or "merge"
providers = models_cfg.setdefault("providers", {})
existing_provider = providers.get(provider_id) or {}
existing_api_key = existing_provider.get("apiKey")
existing_models = existing_provider.get("models")

merged_models = []
if isinstance(existing_models, list):
    for item in existing_models:
        if not isinstance(item, dict):
            continue
        merged_models.append(item)

if not any(item.get("id") == model_id for item in merged_models):
    merged_models.append(model_defaults)

providers[provider_id] = {
    **{k: v for k, v in existing_provider.items() if k not in {"apiKey", "models", "api", "baseUrl"}},
    "baseUrl": base_url,
    "api": "openai-completions",
    **({"apiKey": api_key} if api_key else ({"apiKey": existing_api_key} if existing_api_key else {})),
    "models": merged_models or [model_defaults],
}

config_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
print(f"Updated {config_path} for {primary_model} via custom provider {provider_id}.")
PY
}

if ! command -v openclaw >/dev/null 2>&1; then
  echo "Installing OpenClaw CLI..."
  SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g --prefix "${HOME}/.local" openclaw@latest
  export PATH="${HOME}/.local/bin:${PATH}"
  hash -r
fi

echo "OpenClaw ready: $(openclaw --version)"

mkdir -p "${OPENCLAW_WORKSPACE}"

if [ -f "${OPENCLAW_CONFIG_FILE}" ]; then
  echo "OpenClaw is already configured for this lab."
  normalize_lab_openclaw_config
  echo
  openclaw config file
  echo
  bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
  bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure
  exit 0
fi

openclaw onboard \
  --accept-risk \
  --non-interactive \
  --workspace "${OPENCLAW_WORKSPACE}" \
  --mode local \
  --flow quickstart \
  --auth-choice custom-api-key \
  --custom-base-url "${OPENCLAW_LLM_API_BASE}" \
  --custom-model-id "${OPENCLAW_LLM_MODEL}" \
  --custom-api-key "${LLM_API_KEY}" \
  --custom-provider-id "${OPENCLAW_CUSTOM_PROVIDER_ID}" \
  --custom-compatibility openai \
  --skip-health \
  --skip-channels \
  --skip-skills \
  --skip-ui

normalize_lab_openclaw_config

echo
openclaw config file
echo
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" stop >/dev/null 2>&1 || true
bash "${ROOT_DIR}/scripts/manage_openclaw_gateway.sh" ensure
