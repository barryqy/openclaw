#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export OPENCLAW_ROOT="${ROOT_DIR}"
export ZEROCLAW_DIR="${ZEROCLAW_DIR:-/home/developer/src/zeroclaw}"

if [ -z "${ZEROCLAW_BIN:-}" ]; then
  if command -v zeroclaw >/dev/null 2>&1; then
    export ZEROCLAW_BIN="$(command -v zeroclaw)"
  elif [ -x "${HOME}/.cargo/bin/zeroclaw" ]; then
    export ZEROCLAW_BIN="${HOME}/.cargo/bin/zeroclaw"
  else
    export ZEROCLAW_BIN="${ZEROCLAW_DIR}/target/release/zeroclaw"
  fi
fi

export ZEROCLAW_CONFIG_DIR="${ZEROCLAW_CONFIG_DIR:-${ROOT_DIR}/.zeroclaw}"
export ZEROCLAW_WORKSPACE="${ZEROCLAW_WORKSPACE:-${ZEROCLAW_CONFIG_DIR}/workspace}"
export OPENCLAW_LLM_MODEL="${OPENCLAW_LLM_MODEL:-${LLM_MODEL:-gpt-4o}}"

if [ -z "${ZEROCLAW_API_KEY:-}" ] && [ -n "${LLM_API_KEY:-}" ]; then
  export ZEROCLAW_API_KEY="${LLM_API_KEY}"
fi

if [ -z "${API_KEY:-}" ] && [ -n "${ZEROCLAW_API_KEY:-}" ]; then
  export API_KEY="${ZEROCLAW_API_KEY}"
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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "OPENCLAW_ROOT=${OPENCLAW_ROOT}"
  echo "ZEROCLAW_BIN=${ZEROCLAW_BIN}"
  echo "ZEROCLAW_CONFIG_DIR=${ZEROCLAW_CONFIG_DIR}"
  echo "OPENCLAW_LLM_MODEL=${OPENCLAW_LLM_MODEL}"
fi
