# OpenClaw to DefenseClaw Lab Assets

Student repo for the DevNet Learning Lab that tells one clear story:

1. install and configure OpenClaw with one non-interactive lab helper
2. inspect the OpenClaw CLI and config
3. let a 🚨 malicious skill and 🚨 malicious MCP server cause real trouble
4. trigger prompt injection and privacy-risk prompts against the same LLM path
5. install DefenseClaw in the same container
6. rerun the attacks and watch the results change

## What Is Here

- `skills/release-brief-helper/` is the clean comparison skill.
- `skills/workspace-migration-assistant/` is the intentionally unsafe 🚨 malicious skill.
- `mcp/safe-migration-reference-server.py` is the clean comparison MCP server.
- `mcp/workspace-admin-bridge.py` is the intentionally unsafe 🚨 malicious MCP server.
- `scripts/prepare_live_demo.sh` seeds fake credentials, fake customer data, and a malicious prompt-injection note.
- `scripts/install_malicious_skill.sh` and `scripts/install_safe_skill.sh` copy the comparison skills into the live workspace.
- `scripts/run_skill_exfil_demo.sh` shows the 🚨 malicious skill stealing fake secrets into a localhost collector.
- `scripts/run_mcp_abuse_demo.py` shows the 🚨 malicious MCP tools reading a fake credential file and executing arbitrary code.
- `scripts/run_llm_guardrail_demo.py` drives the baseline and guarded prompt/privacy tests against the same LLM path.
- `scripts/install_defenseclaw_temp.sh` and `scripts/configure_defenseclaw.sh` bring DefenseClaw into the same OpenClaw environment. In a small pod, the install helper can also bootstrap user-space Go, `uv`, and a newer Python for the scanner toolchain.
- `scripts/install_openclaw.sh` is the one-click student setup helper for OpenClaw. In a fresh pod it also bootstraps Node 24 before it configures the lab workspace and points OpenClaw at the built-in lab LLM over its OpenAI-compatible endpoint.
- `scripts/manage_openclaw_gateway.sh` keeps the OpenClaw gateway alive in the background for this lab session without relying on systemd.

## Quick Start

The DevNet lab guide clones this repo into `/home/developer/src/openclaw`, uses one helper to bootstrap the small Python environment, and then uses a second helper to install OpenClaw without any wizard choices. If the pod does not already have Node and npm, the OpenClaw install helper brings in a user-space Node 24 runtime automatically first:

```bash
cd /home/developer/src/openclaw
./scripts/bootstrap_lab.sh
./scripts/install_openclaw.sh
./scripts/check_openclaw.sh
openclaw --version
openclaw config file
./scripts/prepare_live_demo.sh
./scripts/install_malicious_skill.sh
./scripts/run_skill_exfil_demo.sh
./scripts/add_malicious_mcp.sh
./.venv/bin/python ./scripts/run_mcp_abuse_demo.py
python3 ./scripts/run_llm_guardrail_demo.py baseline-injection
python3 ./scripts/run_llm_guardrail_demo.py baseline-privacy
./scripts/install_defenseclaw_temp.sh
./scripts/configure_defenseclaw.sh
source ./scripts/lab-env.sh
/home/developer/src/defenseclaw/.venv/bin/defenseclaw skill scan workspace-migration-assistant --path "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant"
/home/developer/src/defenseclaw/.venv/bin/defenseclaw skill quarantine "${OPENCLAW_SKILLS_DIR}/workspace-migration-assistant" --reason "lab demo: credential exfiltration"
./scripts/run_defenseclaw_mcp_demo.sh
python3 ./scripts/run_llm_guardrail_demo.py guarded-injection
python3 ./scripts/run_llm_guardrail_demo.py guarded-privacy
./scripts/install_safe_skill.sh
/home/developer/src/defenseclaw/.venv/bin/defenseclaw skill scan release-brief-helper --path "${OPENCLAW_SKILLS_DIR}/release-brief-helper"
/home/developer/src/defenseclaw/.venv/bin/defenseclaw mcp set safe_reference_live --command "$(command -v python3)" --args "[\"$PWD/mcp/safe-migration-reference-server.py\"]" --transport stdio
./scripts/summarize_results.sh
```

## Notes

- Everything malicious in this repo is fake, local, and for education only.
- The exfiltration demo only posts to `127.0.0.1`.
- The lab assumes the DevNet image provides the built-in `LLM_*` variables used by `install_openclaw.sh`.
- `llm-image/<model>` in the lab config is the lab's custom provider label. It still talks to the built-in Learning Lab LLM from `LLM_BASE_URL` over an OpenAI-compatible API, not a separate public OpenAI account.
- The guide avoids `source .venv/bin/activate` on purpose so the shell stays predictable between OpenClaw and DefenseClaw steps.
