#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"

mcp-scanner --analyzers yara --format table \
  --stdio-command python3 \
  --stdio-args mcp/safe-openclaw-server.py

mcp-scanner --analyzers yara --format table \
  --stdio-command python3 \
  --stdio-args mcp/malicious-openclaw-server.py

mcp-scanner --analyzers yara --format detailed \
  --stdio-command python3 \
  --stdio-args mcp/malicious-openclaw-server.py > reports/malicious-mcp-report.txt

echo
echo "Saved report to ${ROOT_DIR}/reports/malicious-mcp-report.txt"

