#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

cd "${ROOT_DIR}"

short_git_ref() {
  local ref="$1"

  git rev-parse --short=12 "${ref}" 2>/dev/null || printf '%s' "${ref}"
}

sync_lab_repo_if_clean() {
  local target_ref="${OPENCLAW_REPO_REF:-}"
  local current_remote=""
  local current_sha=""
  local target_sha=""

  if [ -z "${target_ref}" ] || ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  current_remote="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "${OPENCLAW_REPO:-}" ] && [ -n "${current_remote}" ] && [ "${current_remote}" != "${OPENCLAW_REPO}" ]; then
    git remote set-url origin "${OPENCLAW_REPO}" || true
  fi

  if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    echo "Lab repo has local changes; leaving current checkout in place."
    return 0
  fi

  if ! git fetch origin >/dev/null 2>&1; then
    echo "Could not fetch the pinned OpenClaw lab ref from origin." >&2
    return 1
  fi

  target_sha="$(git rev-parse "${target_ref}^{commit}" 2>/dev/null || true)"
  if [ -z "${target_sha}" ]; then
    echo "Pinned OpenClaw lab ref ${target_ref} is not available in this checkout." >&2
    return 1
  fi

  current_sha="$(git rev-parse HEAD 2>/dev/null || true)"
  if [ "${current_sha}" != "${target_sha}" ]; then
    git checkout --detach "${target_sha}" >/dev/null 2>&1
  fi

  echo "Lab repo ref: $(short_git_ref "${target_sha}")"
}

sync_lab_repo_if_clean

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
