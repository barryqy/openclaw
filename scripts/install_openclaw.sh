#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

openclaw_require_llm

if ! command -v openclaw >/dev/null 2>&1; then
  curl -fsSL https://openclaw.ai/install.sh | bash
  export PATH="${HOME}/.local/bin:${PATH}"
fi

mkdir -p "${OPENCLAW_WORKSPACE}"

if [ -f "${OPENCLAW_CONFIG_FILE}" ]; then
  echo "OpenClaw is already configured for this lab."
  echo
  openclaw config file
  echo
  openclaw gateway status
  exit 0
fi

openclaw onboard \
  --non-interactive \
  --workspace "${OPENCLAW_WORKSPACE}" \
  --mode local \
  --flow quickstart \
  --auth-choice custom-api-key \
  --custom-base-url "${LLM_BASE_URL}" \
  --custom-model-id "${OPENCLAW_LLM_MODEL}" \
  --custom-api-key "${LLM_API_KEY}" \
  --custom-provider-id llm-image \
  --custom-compatibility openai \
  --install-daemon \
  --skip-channels \
  --skip-skills \
  --skip-ui

echo
openclaw config file
echo
openclaw gateway status
