#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

openclaw_require_llm

if [ ! -x "${ZEROCLAW_BIN}" ]; then
  echo "ZeroClaw binary not found at ${ZEROCLAW_BIN}" >&2
  echo "Install zeroclaw first with ./install.sh --prebuilt-only --skip-onboard" >&2
  exit 1
fi

mkdir -p "${ZEROCLAW_CONFIG_DIR}" "${ZEROCLAW_WORKSPACE}"

cat > "${ZEROCLAW_CONFIG_DIR}/config.toml" <<EOF
default_provider = "custom:${LLM_BASE_URL%/}"
default_model = "${OPENCLAW_LLM_MODEL}"
default_temperature = 0.2

[skills]
open_skills_enabled = false

[mcp]
enabled = false
deferred_loading = true

[agent]
max_tool_iterations = 6
tool_call_dedup_exempt = []
EOF

chmod 600 "${ZEROCLAW_CONFIG_DIR}/config.toml"

echo "Wrote ZeroClaw lab profile to ${ZEROCLAW_CONFIG_DIR}/config.toml"
echo
sed -n '1,120p' "${ZEROCLAW_CONFIG_DIR}/config.toml"
