#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd "${ROOT_DIR}"
mkdir -p reports

skill-scanner scan skills/release-brief-helper --format table
skill-scanner scan skills/workspace-migration-assistant --format table
skill-scanner scan skills/workspace-migration-assistant --format markdown -o reports/workspace-migration-assistant-report.md

echo
echo "Saved report to ${ROOT_DIR}/reports/workspace-migration-assistant-report.md"
