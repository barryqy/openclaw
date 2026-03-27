#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"
PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"

if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="$(command -v python3)"
fi

"${ROOT_DIR}/scripts/prepare_live_demo.sh" >/dev/null

mode="${1:-}"
case "${mode}" in
  baseline)
    "${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_llm_guardrail_demo.py" baseline-privacy
    ;;
  guarded)
    "${PYTHON_BIN}" "${ROOT_DIR}/scripts/run_llm_guardrail_demo.py" guarded-privacy
    ;;
  *)
    echo "usage: run_privacy_demo.sh <baseline|guarded>" >&2
    exit 1
    ;;
esac
