#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd "${ROOT_DIR}"

refresh_repo_if_clean() {
  local current_branch=""
  local local_sha=""
  local remote_sha=""

  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    echo "Lab repo has local changes; skipping automatic repo update."
    return 0
  fi

  if ! git fetch origin main >/dev/null 2>&1; then
    return 0
  fi

  local_sha="$(git rev-parse HEAD 2>/dev/null || true)"
  remote_sha="$(git rev-parse origin/main 2>/dev/null || true)"
  if [ -z "${local_sha}" ] || [ -z "${remote_sha}" ] || [ "${local_sha}" = "${remote_sha}" ]; then
    return 0
  fi

  if ! git merge-base --is-ancestor "${local_sha}" "${remote_sha}" >/dev/null 2>&1; then
    echo "Lab repo is not fast-forward to origin/main; leaving it as-is."
    return 0
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ "${current_branch}" != "main" ]; then
    git checkout main >/dev/null 2>&1 || return 0
  fi

  if git pull --ff-only origin main >/dev/null 2>&1; then
    echo "Updated lab repo to latest origin/main."
  fi
}

refresh_repo_if_clean

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
