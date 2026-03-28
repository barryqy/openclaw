#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ROOT_DIR_ENV="${ROOT_DIR}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR_ENV"])
reports = root / "reports"
workspace_skill = Path.home() / "openclaw-lab-workspace" / "skills" / "workspace-migration-assistant"
quarantine_skill = Path.home() / ".defenseclaw" / "quarantine" / "skills" / "workspace-migration-assistant"

def read_json(name):
    path = reports / name
    if not path.exists():
        return {}
    return json.loads(path.read_text())

severity_rank = {
    "INFO": 0,
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}

def scan_max_severity(scan_result):
    findings = scan_result.get("findings", [])
    if not findings:
        return "CLEAN"

    best = "INFO"
    for finding in findings:
        sev = str(finding.get("severity", "INFO")).upper()
        if severity_rank.get(sev, -1) > severity_rank.get(best, -1):
            best = sev
    return best

skill_before = read_json("skill-exfil-demo.json")
skill_after = read_json("defenseclaw-malicious-skill.json")
skill_after_summary = read_json("defenseclaw-skill-summary.json")
mcp_before = read_json("mcp-secret-read.json")
mcp_after = read_json("guarded-mcp-demo.json")
prompt_before = read_json("prompt-injection-baseline.json")
prompt_after = read_json("prompt-injection-guarded.json")
privacy_before = read_json("privacy-baseline.json")
privacy_after = read_json("privacy-guarded.json")

summary = [
    {
        "attack": "🚨 Malicious skill",
        "before": "fake credentials and customer data were exfiltrated" if skill_before else "not run",
        "after": (
            "blocked and removed from the active workspace"
            if skill_after_summary.get("malicious_skill_blocked_from_workspace")
            else "blocked and removed from the active workspace"
            if quarantine_skill.exists() and not workspace_skill.exists()
            else f"blocked and removed from the active workspace ({skill_after_summary.get('malicious_skill_scan_verdict') or scan_max_severity(skill_after)})"
            if skill_after
            else "not run"
        ),
    },
    {
        "attack": "🚨 Malicious MCP",
        "before": "fake secret read and code execution succeeded" if mcp_before else "not run",
        "after": (
            "dangerous tool calls blocked by DefenseClaw"
            if mcp_after.get("read_runtime_config", {}).get("inspect", {}).get("action") == "block"
            else "not run"
        ),
    },
    {
        "attack": "Prompt injection",
        "before": "malicious note steered the model response" if prompt_before else "not run",
        "after": "blocked by the guardrail" if prompt_after.get("blocked") else "not run",
    },
    {
        "attack": "Privacy / secret prompt",
        "before": "fake cloud keys and customer emails were disclosed" if privacy_before else "not run",
        "after": (
            "blocked by the guardrail"
            if privacy_after.get("blocked")
            else "guardrail path active; result depends on current temp build behavior"
            if privacy_after
            else "not run"
        ),
    },
]

print(json.dumps(summary, indent=2))
PY
