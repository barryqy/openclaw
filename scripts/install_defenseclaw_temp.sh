#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd /home/developer/src

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "Cloning DefenseClaw from ${DEFENSECLAW_TEMP_REPO}..."
  git clone "${DEFENSECLAW_TEMP_REPO}" "${DEFENSECLAW_DIR}"
fi

cd "${DEFENSECLAW_DIR}"
make install

# shellcheck disable=SC1091
source .venv/bin/activate
./scripts/setup-scanners.sh
defenseclaw init --skip-install
defenseclaw policy activate strict
defenseclaw status
