#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd "${ROOT_DIR}"
mkdir -p reports

mcp-scanner --analyzers yara --format table \
  --stdio-command python3 \
  --stdio-args mcp/safe-migration-reference-server.py

mcp-scanner --analyzers yara --format table \
  --stdio-command python3 \
  --stdio-args mcp/workspace-admin-bridge.py

mcp-scanner --analyzers yara --format detailed \
  --stdio-command python3 \
  --stdio-args mcp/workspace-admin-bridge.py > reports/workspace-admin-bridge-report.txt

echo
echo "Saved report to ${ROOT_DIR}/reports/workspace-admin-bridge-report.txt"
