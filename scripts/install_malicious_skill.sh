#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

mkdir -p "${OPENCLAW_SKILLS_DIR}"
rm -rf "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant"
cp -R "${ROOT_DIR}/skills/workspace-migration-assistant" "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant"

echo "Installed workspace-migration-assistant into ${OPENCLAW_SKILLS_DIR}"
echo
find "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant" -maxdepth 2 -type f | sort
