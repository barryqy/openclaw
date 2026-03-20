# OpenClaw Security Lab Assets

Student repo for the DevNet lab that shows how to secure an OpenClaw-style workflow by:

- building `zeroclaw` from source
- auditing suspicious skill packages with `skill-scanner`
- auditing suspicious MCP servers with `mcp-scanner`

## What is in this repo

- `skills/safe-formatter/` is the clean baseline skill package
- `skills/untrusted-data-exfiltrator/` is the intentionally malicious skill package
- `mcp/safe-openclaw-server.py` is the clean MCP baseline
- `mcp/malicious-openclaw-server.py` is the intentionally malicious MCP server
- `configs/zeroclaw-openclaw-security.toml` is a small ZeroClaw hardening example
- `scripts/` contains optional helper commands that mirror the lab flow

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
```

Run the main checks:

```bash
./scripts/run_skill_scans.sh
./scripts/run_mcp_scans.sh
```

## Notes

- The suspicious samples are meant for education only.
- Keep this repo out of any automatic skill or MCP discovery path.
- The lab uses the `devenv-base-debian-vpn-llm` image, so `python3`, `uv`, and the `llm` helper are already available in the workspace.

