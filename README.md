# OpenClaw to DefenseClaw Lab Assets

Student repo for the DevNet Learning Lab that tells one clear story:

1. start from the image's preloaded OpenClaw setup
2. prove the agent is alive
3. let a malicious skill and MCP server cause real trouble
4. trigger prompt injection and privacy-risk prompts against the same LLM path
5. install DefenseClaw in the same container
6. rerun the attacks and watch the results change

## What Is Here

- `notes/openclaw-cutover-brief.md` is the short launch note used by the OpenClaw smoke test.
- `skills/release-brief-helper/` is the clean comparison skill.
- `skills/workspace-migration-assistant/` is the intentionally unsafe skill.
- `mcp/safe-migration-reference-server.py` is the clean comparison MCP server.
- `mcp/workspace-admin-bridge.py` is the intentionally unsafe MCP server.
- `scripts/prepare_live_demo.sh` seeds fake credentials, fake customer data, and a malicious prompt-injection note.
- `scripts/run_skill_exfil_demo.sh` shows the malicious skill stealing fake secrets into a localhost collector.
- `scripts/run_mcp_abuse_demo.sh` shows the malicious MCP tools reading a fake credential file and executing arbitrary code.
- `scripts/run_prompt_injection_demo.sh` and `scripts/run_privacy_demo.sh` drive direct LLM tests before and after DefenseClaw.
- `scripts/install_defenseclaw_temp.sh` and `scripts/configure_defenseclaw.sh` bring DefenseClaw into the same OpenClaw environment.
- `scripts/install_openclaw.sh` is kept as the image-prep and recovery helper, not the student-facing path.

## Quick Start

The DevNet lab guide clones this repo into `/home/developer/src/openclaw`, verifies the image's preloaded OpenClaw setup, and then uses short helper scripts like these:

```bash
cd /home/developer/src/openclaw
./scripts/bootstrap_lab.sh
./scripts/check_openclaw.sh
./scripts/run_openclaw_smoke_test.sh
./scripts/prepare_live_demo.sh
./scripts/install_malicious_skill.sh
./scripts/run_skill_exfil_demo.sh
./scripts/add_malicious_mcp.sh
./scripts/run_mcp_abuse_demo.sh
./scripts/run_prompt_injection_demo.sh baseline
./scripts/run_privacy_demo.sh baseline
./scripts/install_defenseclaw_temp.sh
./scripts/configure_defenseclaw.sh
./scripts/run_defenseclaw_skill_demo.sh
./scripts/run_defenseclaw_mcp_demo.sh
./scripts/run_prompt_injection_demo.sh guarded
./scripts/run_privacy_demo.sh guarded
./scripts/summarize_results.sh
```

## Notes

- Everything malicious in this repo is fake, local, and for education only.
- The exfiltration demo only posts to `127.0.0.1`.
- The lab assumes the DevNet image already provides the built-in `LLM_*` variables and a preconfigured OpenClaw install.
