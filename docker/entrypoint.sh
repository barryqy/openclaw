#!/usr/bin/env bash

set -euo pipefail

export HOME="${HOME:-/home/developer}"
export OPENCLAW_HOME="${OPENCLAW_HOME:-${HOME}}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-${OPENCLAW_HOME}/.openclaw}"
export DEFENSECLAW_HOME="${DEFENSECLAW_HOME:-${HOME}/.defenseclaw}"
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

mkdir -p "${OPENCLAW_STATE_DIR}" "${DEFENSECLAW_HOME}" /workspace

if [ "${1:-}" = "bash" ] || [ "${1:-}" = "/bin/bash" ] || [ "$#" -eq 0 ]; then
  cat <<'EOF'
OpenClaw + DefenseClaw container is ready.

First run inside this container:
  openclaw-setup

That helper runs the real OpenClaw onboarding flow in local mode, then offers
to enable DefenseClaw guardrails on top of the config you just chose.

Raw commands if you want them:
  openclaw onboard --mode local
  defenseclaw init --enable-guardrail
EOF
  echo
fi

exec "$@"
