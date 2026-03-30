#!/usr/bin/env bash

set -euo pipefail

export HOME="${HOME:-/home/developer}"
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

run_guardrail_setup="yes"
onboard_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-defenseclaw)
      run_guardrail_setup="no"
      ;;
    *)
      onboard_args+=("$1")
      ;;
  esac
  shift
done

if [ ! -f "${HOME}/.openclaw/openclaw.json" ]; then
  openclaw onboard --mode local "${onboard_args[@]}"
else
  echo "OpenClaw already has a config at ${HOME}/.openclaw/openclaw.json."
  echo "Skipping onboarding and moving to the DefenseClaw step."
fi

if [ "${run_guardrail_setup}" = "no" ]; then
  echo
  echo "Skipped DefenseClaw guardrail setup."
  echo "Run 'defenseclaw init --enable-guardrail' later when you want it."
  exit 0
fi

if [ -t 0 ]; then
  printf "\nEnable DefenseClaw guardrails now? [Y/n] "
  read -r answer
  answer="${answer:-Y}"
  case "${answer}" in
    [Nn]*)
      echo "Skipping DefenseClaw guardrail setup."
      echo "Run 'defenseclaw init --enable-guardrail' later when you want it."
      exit 0
      ;;
  esac
fi

exec defenseclaw init --enable-guardrail
