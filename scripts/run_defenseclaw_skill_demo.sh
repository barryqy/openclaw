#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lab-env.sh"

if [ ! -d "${DEFENSECLAW_DIR}" ]; then
  echo "DefenseClaw repo not found at ${DEFENSECLAW_DIR}." >&2
  exit 1
fi

cd "${ROOT_DIR}"
./scripts/install_malicious_skill.sh

cd "${DEFENSECLAW_DIR}"
# shellcheck disable=SC1091
source .venv/bin/activate

defenseclaw skill scan release-brief-helper \
  --path "${ROOT_DIR}/skills/release-brief-helper" \
  --json > "${ROOT_DIR}/reports/defenseclaw-safe-skill.json"

defenseclaw skill scan workspace-migration-assistant \
  --path "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant" \
  --json > "${ROOT_DIR}/reports/defenseclaw-malicious-skill.json"

ROOT_DIR_ENV="${ROOT_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
safe = json.loads((root / "reports" / "defenseclaw-safe-skill.json").read_text())
bad = json.loads((root / "reports" / "defenseclaw-malicious-skill.json").read_text())

severity_rank = {
    "CRITICAL": 4,
    "HIGH": 3,
    "MEDIUM": 2,
    "LOW": 1,
    "INFO": 0,
}

def max_severity(scan_result):
    findings = scan_result.get("findings", [])
    if not findings:
        return "CLEAN"

    best = "INFO"
    for finding in findings:
        sev = str(finding.get("severity", "INFO")).upper()
        if severity_rank.get(sev, -1) > severity_rank.get(best, -1):
            best = sev
    return best

top_findings = sorted(
    bad.get("findings", []),
    key=lambda item: severity_rank.get(str(item.get("severity", "INFO")).upper(), -1),
    reverse=True,
)

print("DefenseClaw skill scan comparison")
print(f"- release-brief-helper: {max_severity(safe)}")
print(f"- workspace-migration-assistant: {max_severity(bad)}")
print()
print("Top findings in the 🚨 malicious skill")
for finding in top_findings[:3]:
    severity = str(finding.get("severity", "INFO")).upper()
    title = finding.get("title", "Untitled finding")
    location = finding.get("location", "unknown location")
    print(f"- {severity}: {title} ({location})")
PY

defenseclaw skill quarantine "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant" \
  --reason "lab demo: credential exfiltration"

python3 - <<'PY'
from pathlib import Path

workspace_path = Path.home() / "openclaw-lab-workspace" / "skills" / "workspace-migration-assistant"
quarantine_path = Path.home() / ".defenseclaw" / "quarantine" / "skills" / "workspace-migration-assistant"

print()
print("DefenseClaw skill enforcement check")
print(f"- active_workspace_path_exists: {workspace_path.exists()}")
print(f"- quarantine_path_exists: {quarantine_path.exists()}")
print(f"- quarantine_path: {quarantine_path}")
PY

echo
if "${ROOT_DIR}/scripts/run_skill_exfil_demo.sh" >/tmp/openclaw-defenseclaw-skill.log 2>&1; then
  cat /tmp/openclaw-defenseclaw-skill.log
  echo "The 🚨 malicious skill still ran after DefenseClaw blocked it." >&2
  exit 1
fi

echo "Replay blocked: the 🚨 malicious skill is no longer in the active workspace."
cat /tmp/openclaw-defenseclaw-skill.log

ROOT_DIR_ENV="${ROOT_DIR}" OPENCLAW_SKILLS_DIR_ENV="${OPENCLAW_SKILLS_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
skills_dir = Path(os.environ["OPENCLAW_SKILLS_DIR_ENV"])
safe = json.loads((root / "reports" / "defenseclaw-safe-skill.json").read_text())
bad = json.loads((root / "reports" / "defenseclaw-malicious-skill.json").read_text())

severity_rank = {
    "INFO": 0,
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}

def max_severity(scan_result):
    findings = scan_result.get("findings", [])
    if not findings:
        return "CLEAN"

    best = "INFO"
    for finding in findings:
        sev = str(finding.get("severity", "INFO")).upper()
        if severity_rank.get(sev, -1) > severity_rank.get(best, -1):
            best = sev
    return best

summary = {
    "safe_skill_scan_verdict": max_severity(safe),
    "malicious_skill_scan_verdict": max_severity(bad),
    "malicious_skill_top_findings": [
        {
            "severity": str(finding.get("severity", "INFO")).upper(),
            "title": finding.get("title", "Untitled finding"),
            "location": finding.get("location", "unknown location"),
        }
        for finding in sorted(
            bad.get("findings", []),
            key=lambda item: severity_rank.get(str(item.get("severity", "INFO")).upper(), -1),
            reverse=True,
        )[:3]
    ],
    "malicious_skill_quarantine_path": str(
        Path.home() / ".defenseclaw" / "quarantine" / "skills" / "workspace-migration-assistant"
    ),
    "malicious_skill_blocked_from_workspace": not (skills_dir / "workspace-migration-assistant").exists(),
    "malicious_skill_exfiltration_replay_blocked": True,
}
summary_path = root / "reports" / "defenseclaw-skill-summary.json"
summary_path.parent.mkdir(parents=True, exist_ok=True)
summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
PY
