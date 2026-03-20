# OpenClaw Security Lab Assets

Student repo for the DevNet lab that starts with a working ZeroClaw agent and then shows how believable extensions can turn that clean runtime into a risky one.

## Lab Story

1. Build `zeroclaw` from source.
2. Create a repo-local ZeroClaw profile that uses the lab image's `LLM_*` settings.
3. Run a clean one-shot agent prompt to prove the runtime works.
4. Install a suspicious migration skill and wire a suspicious MCP server.
5. Scan both with Cisco scanners and explain the findings.

## What Is in This Repo

- `notes/openclaw-cutover-brief.md` is the short brief used by the agent smoke test.
- `skills/release-brief-helper/` is the clean baseline skill package.
- `skills/workspace-migration-assistant/` is the intentionally malicious skill package.
- `mcp/safe-migration-reference-server.py` is the clean MCP baseline.
- `mcp/workspace-admin-bridge.py` is the intentionally unsafe MCP server.
- `configs/zeroclaw-openclaw-security.toml` is the hardened reference profile from the last module.
- `scripts/` contains helper commands that match the lab flow.

## Quick Start

The DevNet lab guide assumes this repo is already present at `/home/developer/src/openclaw`.

```bash
cd /home/developer/src/openclaw

if [ ! -d .venv ]; then
  uv venv --python 3.13 .venv
fi

source .venv/bin/activate
uv pip install cisco-ai-skill-scanner
uv pip install /home/developer/src/mcp-scanner
uv pip install -r requirements.txt

source scripts/lab-env.sh
./scripts/setup_zeroclaw_profile.sh
./scripts/run_agent_smoke_test.sh
./scripts/install_malicious_skill.sh
./scripts/enable_malicious_mcp.sh
./scripts/run_skill_scans.sh
./scripts/run_mcp_scans.sh
```

## Notes

- The suspicious samples are meant for education only.
- Keep this repo out of any automatic skill or MCP discovery path.
- The lab uses the `devenv-base-debian-vpn-llm` image, so `python3`, `uv`, and the `LLM_*` variables are expected to be present in the lab shell.
