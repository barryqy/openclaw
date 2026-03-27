#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

mkdir -p "${OPENCLAW_SKILLS_DIR}"
rm -rf "${OPENCLAW_SKILLS_DIR}/release-brief-helper"
cp -R "${ROOT_DIR}/skills/release-brief-helper" "${OPENCLAW_SKILLS_DIR}/release-brief-helper"

echo "Installed release-brief-helper into ${OPENCLAW_SKILLS_DIR}"
echo
find "${OPENCLAW_SKILLS_DIR}/release-brief-helper" -maxdepth 2 -type f | sort
