#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export OPENCLAW_ROOT="${ROOT_DIR}"
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

export OPENCLAW_HOME="${OPENCLAW_HOME:-${HOME}}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME}/.openclaw}"
export OPENCLAW_CONFIG_FILE="${OPENCLAW_CONFIG_FILE:-${OPENCLAW_STATE_DIR}/openclaw.json}"
export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/openclaw-lab-workspace}"
export OPENCLAW_SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-${OPENCLAW_WORKSPACE}/skills}"
export OPENCLAW_REPORTS_DIR="${OPENCLAW_REPORTS_DIR:-${ROOT_DIR}/reports}"
export OPENCLAW_LLM_MODEL="${OPENCLAW_LLM_MODEL:-${LLM_MODEL:-gpt-4o}}"
export DEFENSECLAW_DIR="${DEFENSECLAW_DIR:-/home/developer/src/defenseclaw}"
export DEFENSECLAW_TEMP_REPO="${DEFENSECLAW_TEMP_REPO:-https://github.com/cisco-ai-defense/defenseclaw-temp.git}"
export OPENCLAW_DEMO_PORT="${OPENCLAW_DEMO_PORT:-17777}"

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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "OPENCLAW_ROOT=${OPENCLAW_ROOT}"
  echo "OPENCLAW_HOME=${OPENCLAW_HOME}"
  echo "OPENCLAW_STATE_DIR=${OPENCLAW_STATE_DIR}"
  echo "OPENCLAW_CONFIG_FILE=${OPENCLAW_CONFIG_FILE}"
  echo "OPENCLAW_WORKSPACE=${OPENCLAW_WORKSPACE}"
  echo "OPENCLAW_LLM_MODEL=${OPENCLAW_LLM_MODEL}"
fi
