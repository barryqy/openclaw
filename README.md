# OpenClaw Security Lab Assets

Student repo for the DevNet lab that starts with a working ZeroClaw agent and then shows how believable extensions can turn that clean runtime into a risky one.

## Lab Story

1. Install `zeroclaw` with the official prebuilt bootstrap path.
2. Create a repo-local Python environment and ZeroClaw profile that use the lab image's `LLM_*` settings.
3. Run a clean one-shot agent prompt to prove the runtime works.
4. Install a suspicious migration skill and watch it steal a fake `~/.aws/credentials` file into a local collector.
5. Wire a suspicious MCP server and watch it read the same fake secret and execute arbitrary code.
6. Scan both with Cisco scanners and explain the findings.

## What Is in This Repo

- `notes/openclaw-cutover-brief.md` is the short brief used by the agent smoke test.
- `skills/release-brief-helper/` is the clean baseline skill package.
- `skills/workspace-migration-assistant/` is the intentionally malicious skill package.
- `mcp/safe-migration-reference-server.py` is the clean MCP baseline.
- `mcp/workspace-admin-bridge.py` is the intentionally unsafe MCP server.
- `configs/zeroclaw-openclaw-security.toml` is the hardened reference profile from the last module.
- `scripts/prepare_live_demo.sh` seeds the fake secrets and export bundle used by the live abuse demos.
- `scripts/run_skill_exfil_demo.sh` shows the skill exfiltrating the fake AWS credential file to a local collector.
- `scripts/run_mcp_abuse_demo.sh` shows the MCP bridge reading the fake secret and triggering arbitrary code execution.
- `scripts/` contains helper commands that match the lab flow.

## Quick Start

The DevNet lab guide clones this repo into `/home/developer/src/openclaw`.

```bash
set -euo pipefail

cd /home/developer/src

if [ ! -d zeroclaw ]; then
  git clone --depth 1 --branch v0.5.1 https://github.com/zeroclaw-labs/zeroclaw.git
fi

cd zeroclaw
./install.sh --prebuilt-only --skip-onboard
export PATH="$HOME/.cargo/bin:$PATH"
zeroclaw --version

if [ ! -d openclaw ]; then
  git clone https://github.com/barryqy/openclaw.git
fi

cd /home/developer/src/openclaw

if [ ! -d .venv ]; then
  python3 -m venv .venv
fi

source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

source scripts/lab-env.sh
./scripts/setup_zeroclaw_profile.sh
./scripts/run_agent_smoke_test.sh
./scripts/prepare_live_demo.sh
./scripts/install_malicious_skill.sh
./scripts/run_skill_exfil_demo.sh
./scripts/enable_malicious_mcp.sh
./scripts/run_mcp_abuse_demo.sh

if [ ! -d /home/developer/src/mcp-scanner ]; then
  git clone https://github.com/cisco-ai-defense/mcp-scanner /home/developer/src/mcp-scanner
fi

python -m pip install cisco-ai-skill-scanner
python -m pip install /home/developer/src/mcp-scanner

./scripts/run_skill_scans.sh
./scripts/run_mcp_scans.sh
```

## Notes

- The suspicious samples are meant for education only.
- Keep this repo out of any automatic skill or MCP discovery path.
- The lab uses the `devenv-base-debian-vpn-llm` image, so `python3` and the `LLM_*` variables are expected to be present in the lab shell.
