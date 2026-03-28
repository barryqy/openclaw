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
export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/openclaw-lab-workspace}"
export OPENCLAW_SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-${OPENCLAW_WORKSPACE}/skills}"
export OPENCLAW_REPORTS_DIR="${OPENCLAW_REPORTS_DIR:-${ROOT_DIR}/reports}"
export OPENCLAW_GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-127.0.0.1}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export OPENCLAW_GATEWAY_PID_FILE="${OPENCLAW_GATEWAY_PID_FILE:-${OPENCLAW_STATE_DIR}/lab-gateway.pid}"
export OPENCLAW_GATEWAY_LOG_FILE="${OPENCLAW_GATEWAY_LOG_FILE:-${OPENCLAW_STATE_DIR}/lab-gateway.log}"
export OPENCLAW_LLM_MODEL="${OPENCLAW_LLM_MODEL:-${LLM_MODEL:-gpt-4o}}"
export OPENCLAW_CUSTOM_PROVIDER_ID="${OPENCLAW_CUSTOM_PROVIDER_ID:-llm-image}"
export DEFENSECLAW_DIR="${DEFENSECLAW_DIR:-/home/developer/src/defenseclaw}"
export DEFENSECLAW_TEMP_REPO="${DEFENSECLAW_TEMP_REPO:-https://github.com/cisco-ai-defense/defenseclaw-temp.git}"
export OPENCLAW_DEMO_PORT="${OPENCLAW_DEMO_PORT:-17777}"

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
fi
