#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

derive_lab_llm_api_base() {
  local raw_url="${1:-}"

  raw_url="${raw_url%/}"

  case "${raw_url}" in
    */chat/completions)
      printf '%s\n' "${raw_url%/chat/completions}"
      ;;
    */completions)
      printf '%s\n' "${raw_url%/completions}"
      ;;
    *)
      printf '%s\n' "${raw_url}"
      ;;
  esac
}

export OPENCLAW_ROOT="${ROOT_DIR}"
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

tmpOpenclawHome="${OPENCLAW_HOME:-}"
if [ "${tmpOpenclawHome}" = "${HOME}/.openclaw" ]; then
  # Older lab revisions exported the state dir as OPENCLAW_HOME.
  tmpOpenclawHome="${HOME}"
fi

export OPENCLAW_HOME="${tmpOpenclawHome:-${HOME}}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME}/.openclaw}"
export OPENCLAW_CONFIG_FILE="${OPENCLAW_CONFIG_FILE:-${OPENCLAW_STATE_DIR}/openclaw.json}"
export OPENCLAW_EXTENSIONS_DIR="${OPENCLAW_EXTENSIONS_DIR:-${OPENCLAW_STATE_DIR}/extensions}"
export OPENCLAW_DEFENSECLAW_PLUGIN_DIR="${OPENCLAW_DEFENSECLAW_PLUGIN_DIR:-${OPENCLAW_EXTENSIONS_DIR}/defenseclaw}"
export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/openclaw-lab-workspace}"
export OPENCLAW_SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-${OPENCLAW_WORKSPACE}/skills}"
export OPENCLAW_REPORTS_DIR="${OPENCLAW_REPORTS_DIR:-${ROOT_DIR}/reports}"
export OPENCLAW_GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-127.0.0.1}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export OPENCLAW_GATEWAY_PID_FILE="${OPENCLAW_GATEWAY_PID_FILE:-${OPENCLAW_STATE_DIR}/lab-gateway.pid}"
export OPENCLAW_GATEWAY_LOG_FILE="${OPENCLAW_GATEWAY_LOG_FILE:-${OPENCLAW_STATE_DIR}/lab-gateway.log}"
export DEFENSECLAW_CONFIGURED_MARKER_FILE="${DEFENSECLAW_CONFIGURED_MARKER_FILE:-${OPENCLAW_STATE_DIR}/defenseclaw-guardrail-configured}"
export OPENCLAW_LLM_MODEL="${OPENCLAW_LLM_MODEL:-${LLM_MODEL:-gpt-4o}}"
export OPENCLAW_CUSTOM_PROVIDER_ID="${OPENCLAW_CUSTOM_PROVIDER_ID:-llm-image}"
export OPENCLAW_REPO="${OPENCLAW_REPO:-https://github.com/barryqy/openclaw.git}"
export OPENCLAW_REPO_REF="${OPENCLAW_REPO_REF:-fc7493684491d11c62b1ad75598549fb05dc2526}"
export OPENCLAW_NPM_VERSION="${OPENCLAW_NPM_VERSION:-2026.4.21}"
export DEFENSECLAW_DIR="${DEFENSECLAW_DIR:-/home/developer/src/defenseclaw}"
export DEFENSECLAW_INSTALLED_PLUGIN_DIR="${DEFENSECLAW_INSTALLED_PLUGIN_DIR:-${HOME}/.defenseclaw/extensions/defenseclaw}"
defenseclawRepo="${DEFENSECLAW_REPO:-${DEFENSECLAW_TEMP_REPO:-https://github.com/cisco-ai-defense/defenseclaw.git}}"
export DEFENSECLAW_REPO="${defenseclawRepo}"
export DEFENSECLAW_TEMP_REPO="${defenseclawRepo}"
export DEFENSECLAW_VERSION="${DEFENSECLAW_VERSION:-0.8.0}"
export DEFENSECLAW_RELEASE_BASE_URL="${DEFENSECLAW_RELEASE_BASE_URL:-https://github.com/cisco-ai-defense/defenseclaw/releases/download/${DEFENSECLAW_VERSION}}"
export OPENCLAW_OPENSHELL_INSTALL_DIR="${OPENCLAW_OPENSHELL_INSTALL_DIR:-${HOME}/.local/bin}"
export OPENCLAW_OPENSHELL_INSTALLER_URL="${OPENCLAW_OPENSHELL_INSTALLER_URL:-https://raw.githubusercontent.com/cisco-ai-defense/defenseclaw/${DEFENSECLAW_VERSION}/scripts/install-openshell-sandbox.sh}"
export OPENCLAW_OPENSHELL_VERSION="${OPENCLAW_OPENSHELL_VERSION:-0.0.16}"
export OPENCLAW_DEMO_PORT="${OPENCLAW_DEMO_PORT:-17777}"

case "$(uname -m)" in
  x86_64|amd64)
    export OPENCLAW_OPENSHELL_SHA256="${OPENCLAW_OPENSHELL_SHA256:-9a2927b5f405e83a86841fb06389f9a8c89e35792a62f943beb8e6f9f0c2ebf9}"
    export OPENCLAW_OPENSHELL_ARCH_DIGEST="${OPENCLAW_OPENSHELL_ARCH_DIGEST:-sha256:a0b1ec4e7fcbd5538148817b3a31b0d47de1ff79c95adeb30aa082c63721d5aa}"
    ;;
  aarch64|arm64)
    export OPENCLAW_OPENSHELL_SHA256="${OPENCLAW_OPENSHELL_SHA256:-218267d74432698fe630f465d6e9ab156e48fd4b05c4dec77a8dd1791db3ed93}"
    export OPENCLAW_OPENSHELL_ARCH_DIGEST="${OPENCLAW_OPENSHELL_ARCH_DIGEST:-sha256:266c83b1b73b94e89e5641760fb6aba5651b245dc59ab19e76fbf40b8b539ae1}"
    ;;
esac

openclaw_mcp_python() {
  local python_bin="${OPENCLAW_MCP_PYTHON_BIN:-${OPENCLAW_ROOT}/.venv/bin/python}"

  if [ ! -x "${python_bin}" ]; then
    echo "MCP Python runtime not found at ${python_bin}. Run ./scripts/bootstrap_lab.sh first." >&2
    return 1
  fi

  if ! "${python_bin}" -c 'from mcp.server.fastmcp import FastMCP' >/dev/null 2>&1; then
    if [ "${python_bin}" != "${OPENCLAW_ROOT}/.venv/bin/python" ]; then
      echo "${python_bin} cannot import mcp.server.fastmcp. Use the OpenClaw repo venv or install the lab requirements in this venv." >&2
      return 1
    fi

    echo "Installing the clean MCP server dependency in ${python_bin}..." >&2
    if ! "${python_bin}" -m pip install -r "${OPENCLAW_ROOT}/requirements.txt" >&2; then
      echo "Could not install the OpenClaw lab Python requirements." >&2
      return 1
    fi
  fi

  if ! "${python_bin}" -c 'from mcp.server.fastmcp import FastMCP' >/dev/null 2>&1; then
    echo "${python_bin} still cannot import mcp.server.fastmcp." >&2
    return 1
  fi

  printf '%s\n' "${python_bin}"
}

tmpLabApiBase="${OPENCLAW_LLM_API_BASE:-}"
if [ -z "${tmpLabApiBase}" ] && [ -n "${LLM_BASE_URL:-}" ]; then
  tmpLabApiBase="$(derive_lab_llm_api_base "${LLM_BASE_URL}")"
fi
export OPENCLAW_LLM_API_BASE="${tmpLabApiBase}"

if [ -z "${OPENAI_API_KEY:-}" ] && [ -n "${LLM_API_KEY:-}" ]; then
  export OPENAI_API_KEY="${LLM_API_KEY}"
fi

if [ -z "${OPENAI_API_BASE:-}" ] && [ -n "${OPENCLAW_LLM_API_BASE:-}" ]; then
  export OPENAI_API_BASE="${OPENCLAW_LLM_API_BASE}"
fi

if [ -z "${OPENAI_BASE_URL:-}" ] && [ -n "${OPENCLAW_LLM_API_BASE:-}" ]; then
  export OPENAI_BASE_URL="${OPENCLAW_LLM_API_BASE}"
fi

if [ -z "${SKILL_SCANNER_LLM_API_KEY:-}" ] && [ -n "${LLM_API_KEY:-}" ]; then
  export SKILL_SCANNER_LLM_API_KEY="${LLM_API_KEY}"
fi

if [ -z "${SKILL_SCANNER_LLM_BASE_URL:-}" ] && [ -n "${LLM_BASE_URL:-}" ]; then
  export SKILL_SCANNER_LLM_BASE_URL="${LLM_BASE_URL}"
fi

if [ -n "${SKILL_SCANNER_LLM_API_KEY:-}" ] && [ -n "${SKILL_SCANNER_LLM_BASE_URL:-}" ] && [ -z "${SKILL_SCANNER_LLM_MODEL:-}" ]; then
  export SKILL_SCANNER_LLM_MODEL="${OPENCLAW_LLM_MODEL}"
fi

if [ -z "${MCP_SCANNER_LLM_API_KEY:-}" ] && [ -n "${LLM_API_KEY:-}" ]; then
  export MCP_SCANNER_LLM_API_KEY="${LLM_API_KEY}"
fi

if [ -z "${MCP_SCANNER_LLM_BASE_URL:-}" ] && [ -n "${LLM_BASE_URL:-}" ]; then
  export MCP_SCANNER_LLM_BASE_URL="${LLM_BASE_URL}"
fi

if [ -n "${MCP_SCANNER_LLM_API_KEY:-}" ] && [ -n "${MCP_SCANNER_LLM_BASE_URL:-}" ] && [ -z "${MCP_SCANNER_LLM_MODEL:-}" ]; then
  export MCP_SCANNER_LLM_MODEL="${OPENCLAW_LLM_MODEL}"
fi

openclaw_require_llm() {
  if [ -z "${LLM_BASE_URL:-}" ] || [ -z "${LLM_API_KEY:-}" ]; then
    echo "LLM_BASE_URL and LLM_API_KEY must be present in this lab shell." >&2
    return 1
  fi
}

openclaw_use_lab_openai_env() {
  openclaw_require_llm || return 1

  export OPENAI_API_KEY="${LLM_API_KEY}"
  export OPENAI_API_BASE="${OPENCLAW_LLM_API_BASE}"
  export OPENAI_BASE_URL="${OPENCLAW_LLM_API_BASE}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "OPENCLAW_ROOT=${OPENCLAW_ROOT}"
  echo "OPENCLAW_HOME=${OPENCLAW_HOME}"
  echo "OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR}"
  echo "OPENCLAW_CONFIG_FILE=${OPENCLAW_CONFIG_FILE}"
  echo "OPENCLAW_WORKSPACE=${OPENCLAW_WORKSPACE}"
  echo "OPENCLAW_GATEWAY_HOST=${OPENCLAW_GATEWAY_HOST}"
  echo "OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}"
  echo "OPENCLAW_LLM_MODEL=${OPENCLAW_LLM_MODEL}"
  echo "OPENCLAW_REPO_REF=${OPENCLAW_REPO_REF}"
  echo "OPENCLAW_NPM_VERSION=${OPENCLAW_NPM_VERSION}"
  echo "DEFENSECLAW_VERSION=${DEFENSECLAW_VERSION}"
fi
