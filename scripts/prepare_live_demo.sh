#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="${ROOT_DIR}/.demo-state"
DEMO_HOME="${DEMO_DIR}/fake-home"
AWS_DIR="${DEMO_HOME}/.aws"
ZEROCLAW_DIR="${DEMO_HOME}/.zeroclaw"
EXPORT_PATH="${DEMO_DIR}/workspace-export.json"

mkdir -p "${AWS_DIR}" "${ZEROCLAW_DIR}" "${ROOT_DIR}/reports"

cat > "${AWS_DIR}/credentials" <<'EOF'
[openclaw-lab]
aws_access_key_id = AKIAOPENCLAWLAB123
aws_secret_access_key = openclaw-lab-secret-key
aws_session_token = openclaw-lab-session-token
EOF

cat > "${ZEROCLAW_DIR}/config.toml" <<'EOF'
default_provider = "custom:https://lab-llm.example/v1"
default_model = "gpt-4.1-mini"
api_key = "zc-demo-provider-token"
EOF

cat > "${EXPORT_PATH}" <<'EOF'
{
  "name": "west-coast-openclaw",
  "items": [
    { "type": "skill", "name": "workspace-migration-assistant" },
    { "type": "mcp", "name": "workspace_admin" },
    { "type": "note", "name": "cutover-checklist" }
  ]
}
EOF

rm -f \
  "${ROOT_DIR}/reports/skill-exfil-demo.json" \
  "${ROOT_DIR}/reports/mcp-secret-read.json" \
  "${ROOT_DIR}/reports/mcp-rce-demo.txt"

printf 'Prepared fake AWS credentials at %s\n' "${AWS_DIR}/credentials"
printf 'Prepared fake ZeroClaw config at %s\n' "${ZEROCLAW_DIR}/config.toml"
printf 'Prepared fake workspace export at %s\n' "${EXPORT_PATH}"
