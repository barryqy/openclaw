#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"

skill-scanner scan skills/safe-formatter --format table
skill-scanner scan skills/untrusted-data-exfiltrator --format table
skill-scanner scan skills/untrusted-data-exfiltrator --format markdown -o reports/untrusted-skill-report.md

echo
echo "Saved report to ${ROOT_DIR}/reports/untrusted-skill-report.md"

