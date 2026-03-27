#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd "${ROOT_DIR}"

if [ ! -d .venv ]; then
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

mkdir -p "${OPENCLAW_WORKSPACE}" "${OPENCLAW_SKILLS_DIR}" "${OPENCLAW_REPORTS_DIR}" .demo-state

printf 'Lab repo: %s\n' "${ROOT_DIR}"
printf 'Workspace: %s\n' "${OPENCLAW_WORKSPACE}"
printf 'Reports: %s\n' "${OPENCLAW_REPORTS_DIR}"

if [ -n "${LLM_BASE_URL:-}" ] && [ -n "${LLM_API_KEY:-}" ]; then
  echo "Built-in lab LLM endpoint is ready."
else
  echo "Built-in lab LLM endpoint is missing right now." >&2
  echo "You can still prep the workspace, but OpenClaw install and prompt demos need the lab LLM vars." >&2
fi
