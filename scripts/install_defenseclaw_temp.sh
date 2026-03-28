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

python_version_ok() {
  local python_bin="$1"
  local min_major="${2:-3}"
  local min_minor="${3:-10}"

  "${python_bin}" "${min_major}" "${min_minor}" - <<'PY' >/dev/null 2>&1
import sys

min_major = int(sys.argv[1])
min_minor = int(sys.argv[2])

raise SystemExit(0 if sys.version_info >= (min_major, min_minor) else 1)
PY
}

resolve_defenseclaw_python() {
  local candidate
  local uv_python

  for candidate in python3.13 python3.12 python3.11 python3; do
    if ! command -v "${candidate}" >/dev/null 2>&1; then
      continue
    fi

    if python_version_ok "${candidate}" 3 11; then
      command -v "${candidate}"
      return 0
    fi
  done

  uv_python="$(uv python find 3.12 2>/dev/null || true)"
  if [ -n "${uv_python}" ] && [ -x "${uv_python}" ]; then
    echo "${uv_python}"
    return 0
  fi

  echo "Installing Python 3.12 for DefenseClaw..." >&2
  uv python install 3.12
  uv_python="$(uv python find 3.12 2>/dev/null || true)"

  if [ -n "${uv_python}" ] && [ -x "${uv_python}" ]; then
    echo "${uv_python}"
    return 0
  fi

  echo "DefenseClaw needs Python 3.11 or newer so the MCP scanner can install." >&2
  return 1
}

go_runtime_ok() {
  if ! command -v go >/dev/null 2>&1; then
    return 1
  fi

  local go_ver
  local major
  local minor

  go_ver="$(go version 2>/dev/null | awk '{print $3}')"
  go_ver="${go_ver#go}"

  if [ -z "${go_ver}" ]; then
    return 1
  fi

  IFS=. read -r major minor _ <<<"${go_ver}"

  if [ "${major}" -gt 1 ]; then
    return 0
  fi

  [ "${minor}" -ge 25 ]
}

install_go_runtime() {
  local os_name
  local arch
  local go_os
  local go_arch
  local go_ver="1.25.0"
  local archive_name
  local install_root
  local go_bin_dir
  local tmpdir

  os_name="$(uname -s)"
  arch="$(uname -m)"

  case "${os_name}" in
    Linux) go_os="linux" ;;
    Darwin) go_os="darwin" ;;
    *)
      echo "Unsupported operating system for Go bootstrap: ${os_name}" >&2
      return 1
      ;;
  esac

  case "${arch}" in
    x86_64|amd64) go_arch="amd64" ;;
    aarch64|arm64) go_arch="arm64" ;;
    *)
      echo "Unsupported CPU architecture for Go bootstrap: ${arch}" >&2
      return 1
      ;;
  esac

  archive_name="go${go_ver}.${go_os}-${go_arch}.tar.gz"
  install_root="${HOME}/.local/share/defenseclaw-go/go${go_ver}-${go_os}-${go_arch}"
  go_bin_dir="${install_root}/bin"

  if [ ! -x "${go_bin_dir}/go" ]; then
    echo "Installing Go ${go_ver} for DefenseClaw..."
    tmpdir="$(mktemp -d)"
    download_file "https://go.dev/dl/${archive_name}" "${tmpdir}/${archive_name}"
    mkdir -p "${HOME}/.local/share/defenseclaw-go" "${HOME}/.local/bin"
    tar -xzf "${tmpdir}/${archive_name}" -C "${tmpdir}"
    rm -rf "${install_root}"
    mv "${tmpdir}/go" "${install_root}"
    rm -rf "${tmpdir}"
  fi

  mkdir -p "${HOME}/.local/bin"
  ln -sf "${go_bin_dir}/go" "${HOME}/.local/bin/go"
  ln -sf "${go_bin_dir}/gofmt" "${HOME}/.local/bin/gofmt"
  export PATH="${go_bin_dir}:${HOME}/.local/bin:${PATH}"
  hash -r

  if [ ! -x "${go_bin_dir}/go" ]; then
    echo "Go bootstrap completed, but the go binary is missing at ${go_bin_dir}/go." >&2
    return 1
  fi

  echo "Go ready: $("${go_bin_dir}/go" version)"
}

ensure_go_runtime() {
  if go_runtime_ok; then
    return 0
  fi

  install_go_runtime
}

ensure_uv_runtime() {
  local tmpdir

  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  echo "Installing uv for DefenseClaw..."
  tmpdir="$(mktemp -d)"
  download_file "https://astral.sh/uv/install.sh" "${tmpdir}/install-uv.sh"
  mkdir -p "${HOME}/.local/bin"
  UV_UNMANAGED_INSTALL="${HOME}/.local/bin" sh "${tmpdir}/install-uv.sh" --quiet
  rm -rf "${tmpdir}"

  export PATH="${HOME}/.local/bin:${PATH}"

  hash -r

  if ! command -v uv >/dev/null 2>&1; then
    echo "uv was installed, but it is still not on PATH." >&2
    return 1
  fi

  echo "uv ready: $(uv --version)"
}

python_module_available() {
  local python_bin="$1"
  local module_name="$2"

  "${python_bin}" - "${module_name}" <<'PY' >/dev/null 2>&1
import importlib.util
import sys

raise SystemExit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
}

ensure_lab_scanners() {
  local missing=()

  if ! python_module_available ".venv/bin/python" "skill_scanner"; then
    missing+=("cisco-ai-skill-scanner")
  fi

  if ! python_module_available ".venv/bin/python" "mcpscanner"; then
    missing+=("cisco-ai-mcp-scanner")
  fi

  if [ "${#missing[@]}" -eq 0 ]; then
    echo "DefenseClaw scanner dependencies already available in the lab venv."
    echo "Skipping cisco-aibom because this lab does not use AI BOM commands."
    return 0
  fi

  echo "Installing missing DefenseClaw scanner dependencies: ${missing[*]}"
  uv pip install --python .venv/bin/python "${missing[@]}"
  echo "Skipping cisco-aibom because this lab does not use AI BOM commands."
}

patch_defenseclaw_guardrail_api_base() {
  python3 - "${DEFENSECLAW_DIR}" <<'PY'
from pathlib import Path
import re
import sys


root = Path(sys.argv[1])

config_go = root / "internal" / "config" / "config.go"
config_py = root / "cli" / "defenseclaw" / "config.py"
proxy_go = root / "internal" / "gateway" / "proxy.go"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    return text.replace(old, new, 1)


def inject_after_line_once(text: str, anchor: str, addition: str, label: str) -> str:
    if addition.strip() in text:
        return text
    if anchor not in text:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    return text.replace(anchor, anchor + addition, 1)


def guardrail_block(text: str, label: str) -> str:
    match = re.search(r"type GuardrailConfig struct \{\n(?P<body>.*?)\n\}", text, re.S)
    if not match:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    return match.group("body")


def replace_guardrail_block(text: str, transform, label: str) -> str:
    pattern = r"(type GuardrailConfig struct \{\n)(?P<body>.*?)(\n\})"
    match = re.search(pattern, text, re.S)
    if not match:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    body = transform(match.group("body"))
    return text[:match.start()] + match.group(1) + body + match.group(3) + text[match.end():]


def replace_guardrail_dataclass(text: str, transform, label: str) -> str:
    pattern = r"(@dataclass\nclass GuardrailConfig:\n)(?P<body>(?:    .*\n)+)"
    match = re.search(pattern, text)
    if not match:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    body = transform(match.group("body"))
    return text[:match.start()] + match.group(1) + body + text[match.end():]


def replace_guardrail_merge(text: str, transform, label: str) -> str:
    pattern = r"(def _merge_guardrail\(raw: dict\[str, Any\] \| None, data_dir: str\) -> GuardrailConfig:\n.*?return GuardrailConfig\(\n)(?P<body>.*?)(\n    \))"
    match = re.search(pattern, text, re.S)
    if not match:
        raise SystemExit(f"Could not find {label} while patching DefenseClaw for the lab.")
    body = transform(match.group("body"))
    return text[:match.start()] + match.group(1) + body + match.group(3) + text[match.end():]


text = config_go.read_text(encoding="utf-8")
if "APIBase" not in guardrail_block(text, "GuardrailConfig"):
    text = replace_guardrail_block(
        text,
        lambda body: inject_after_line_once(
            body,
            '\tAPIKeyEnv     string      `mapstructure:"api_key_env"     yaml:"api_key_env"`\n',
            '\tAPIBase       string      `mapstructure:"api_base"        yaml:"api_base"`\n',
            "GuardrailConfig.APIBase",
        ),
        "GuardrailConfig",
    )
config_go.write_text(text, encoding="utf-8")

text = config_py.read_text(encoding="utf-8")
guardrail_dataclass = re.search(
    r"@dataclass\nclass GuardrailConfig:\n(?P<body>(?:    .*\n)+)",
    text,
)
if not guardrail_dataclass or 'api_base: str = ""' not in guardrail_dataclass.group("body"):
    text = replace_guardrail_dataclass(
        text,
        lambda body: inject_after_line_once(
            body,
            '    api_key_env: str = ""           # env var holding the API key, e.g. "ANTHROPIC_API_KEY"\n',
            '    api_base: str = ""              # optional custom OpenAI-compatible base URL\n',
            "GuardrailConfig.api_base",
        ),
        "GuardrailConfig dataclass",
    )
merge_guardrail = re.search(
    r"def _merge_guardrail\(raw: dict\[str, Any\] \| None, data_dir: str\) -> GuardrailConfig:\n.*?return GuardrailConfig\(\n(?P<body>.*?)\n    \)",
    text,
    re.S,
)
if not merge_guardrail or 'api_base=raw.get("api_base", ""),' not in merge_guardrail.group("body"):
    text = replace_guardrail_merge(
        text,
        lambda body: inject_after_line_once(
            body,
            '        api_key_env=raw.get("api_key_env", ""),\n',
            '        api_base=raw.get("api_base", ""),\n',
            "_merge_guardrail api_base",
        ),
        "_merge_guardrail",
    )
config_py.write_text(text, encoding="utf-8")

text = proxy_go.read_text(encoding="utf-8")
if "NewProviderWithBase(cfg.Model, apiKey, cfg.APIBase)" not in text:
    text = replace_once(
        text,
        "provider, err := NewProvider(cfg.Model, apiKey)\n"
        "\tif err != nil {\n"
        '\t\treturn nil, fmt.Errorf("proxy: create provider: %w", err)\n'
        "\t}\n",
        "provider := NewProviderWithBase(cfg.Model, apiKey, cfg.APIBase)\n",
        "guardrail provider wiring",
    )
    proxy_go.write_text(text, encoding="utf-8")
PY

  if command -v gofmt >/dev/null 2>&1; then
    gofmt -w internal/config/config.go internal/gateway/proxy.go
  fi
}

defenseclaw_parent_dir="$(dirname "${DEFENSECLAW_DIR}")"
mkdir -p "${defenseclaw_parent_dir}"
cd "${defenseclaw_parent_dir}"

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "Cloning DefenseClaw from ${DEFENSECLAW_TEMP_REPO}..."
  git clone "${DEFENSECLAW_TEMP_REPO}" "${DEFENSECLAW_DIR}"
fi

cd "${DEFENSECLAW_DIR}"

ensure_go_runtime
ensure_uv_runtime
patch_defenseclaw_guardrail_api_base

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to build the DefenseClaw plugin." >&2
  echo "Run the OpenClaw install step first so Node.js is bootstrapped into the lab pod." >&2
  exit 1
fi

UV_PYTHON_BIN="$(resolve_defenseclaw_python)"

if [ -x ".venv/bin/python" ] && ! python_version_ok ".venv/bin/python" 3 11; then
  rm -rf .venv
fi

uv venv .venv --python "${UV_PYTHON_BIN}"
uv pip install -e . --python .venv/bin/python
export npm_config_audit=false
export npm_config_fund=false
export npm_config_update_notifier=false
make gateway-install plugin-install
hash -r

if ! command -v defenseclaw-gateway >/dev/null 2>&1; then
  echo
  echo "DefenseClaw gateway is still not on PATH after the first install pass." >&2
  echo "Recovery: run 'make gateway-install' from ${DEFENSECLAW_DIR} and then rerun this helper." >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate
ensure_lab_scanners
defenseclaw init --skip-install
defenseclaw policy activate strict
defenseclaw status
