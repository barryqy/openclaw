#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/reports"

cd "${ROOT_DIR}"
./scripts/install_safe_skill.sh >/dev/null

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

defenseclaw skill scan release-brief-helper \
  --path "${OPENCLAW_SKILLS_DIR}/release-brief-helper" \
  --json > "${ROOT_DIR}/reports/defenseclaw-safe-skill-deploy.json"

safe_mcp_output="$(defenseclaw mcp set safe_reference_live \
  --command "$(command -v python3)" \
  --args "[\"${ROOT_DIR}/mcp/safe-migration-reference-server.py\"]" \
  --transport stdio 2>&1)"

printf '%s\n' "${safe_mcp_output}" > "${ROOT_DIR}/reports/defenseclaw-safe-mcp-deploy.txt"
printf '%s\n' "${safe_mcp_output}"

ROOT_DIR_ENV="${ROOT_DIR}" OPENCLAW_SKILLS_DIR_ENV="${OPENCLAW_SKILLS_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
skills_dir = Path(os.environ["OPENCLAW_SKILLS_DIR_ENV"])
safe_skill = json.loads((root / "reports" / "defenseclaw-safe-skill-deploy.json").read_text())
mcp_text = (root / "reports" / "defenseclaw-safe-mcp-deploy.txt").read_text(encoding="utf-8")

def scan_verdict(scan_result):
    findings = scan_result.get("findings", [])
    if not findings:
        return "CLEAN"
    return "FINDINGS_PRESENT"

summary = {
    "safe_skill_scan_verdict": scan_verdict(safe_skill),
    "safe_skill_installed": (skills_dir / "release-brief-helper").exists(),
    "safe_mcp_name": "safe_reference_live",
    "safe_mcp_registered": "Added MCP server: safe_reference_live" in mcp_text,
}

summary_path = root / "reports" / "defenseclaw-safe-extension-summary.json"
summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
PY
