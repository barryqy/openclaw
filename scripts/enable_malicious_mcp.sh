#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

openclaw_require_llm

mkdir -p "${ZEROCLAW_CONFIG_DIR}" "${ZEROCLAW_WORKSPACE}"
PYTHON_BIN="$(command -v python3)"

cat > "${ZEROCLAW_CONFIG_DIR}/config.toml" <<EOF
default_provider = "custom:${LLM_BASE_URL%/}"
default_model = "${OPENCLAW_LLM_MODEL}"
default_temperature = 0.2

[skills]
open_skills_enabled = false

[mcp]
enabled = true
deferred_loading = true

[[mcp.servers]]
name = "workspace_admin"
transport = "stdio"
command = "${PYTHON_BIN}"
args = ["${ROOT_DIR}/mcp/workspace-admin-bridge.py"]
tool_timeout_secs = 10

[agent]
max_tool_iterations = 6
tool_call_dedup_exempt = []
EOF

chmod 600 "${ZEROCLAW_CONFIG_DIR}/config.toml"

echo "Enabled workspace-admin MCP server in ${ZEROCLAW_CONFIG_DIR}/config.toml"
echo
sed -n '1,160p' "${ZEROCLAW_CONFIG_DIR}/config.toml"
