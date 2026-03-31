#!/usr/bin/env python3
"""Mirror the DefenseClaw tool-inspection flow for the malicious MCP tools."""

from __future__ import annotations

import hashlib
import hmac
import importlib.util
import json
import os
import sys
from pathlib import Path

import requests
import yaml


ROOT_DIR = Path(__file__).resolve().parent.parent


def read_dotenv_token(key: str) -> str:
    env_path = Path.home() / ".defenseclaw" / ".env"
    if not env_path.exists():
        return ""

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        env_key, env_value = line.split("=", 1)
        if env_key.strip() == key:
            return env_value.strip()

    return ""


def derive_sidecar_master_key(device_key_file: str) -> str:
    candidates = [device_key_file, str(Path.home() / ".defenseclaw" / "device.key")]

    for raw_path in candidates:
        if not raw_path:
            continue

        path = Path(raw_path).expanduser()
        try:
            digest = hmac.new(
                b"defenseclaw-proxy-master-key",
                path.read_bytes(),
                hashlib.sha256,
            ).hexdigest()[:32]
        except OSError:
            continue

        return f"sk-dc-{digest}"

    return ""


def load_sidecar_settings() -> tuple[str, str, str]:
    cfg_path = Path.home() / ".defenseclaw" / "config.yaml"
    host = "127.0.0.1"
    api_port = 18970
    token = ""
    token_env = "OPENCLAW_GATEWAY_TOKEN"
    device_key_file = str(Path.home() / ".defenseclaw" / "device.key")

    if cfg_path.exists():
        cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
        gateway_cfg = cfg.get("gateway", {})
        host = str(gateway_cfg.get("host", host) or host)
        api_port = int(gateway_cfg.get("api_port", api_port))
        token = str(gateway_cfg.get("token", "") or "")
        token_env = str(gateway_cfg.get("token_env", token_env) or token_env)
        device_key_file = str(gateway_cfg.get("device_key_file", device_key_file) or device_key_file)

    env_token = os.environ.get(token_env, "") or os.environ.get("OPENCLAW_GATEWAY_TOKEN", "")
    if env_token:
        token = env_token
    elif not token:
        token = read_dotenv_token(token_env) or read_dotenv_token("OPENCLAW_GATEWAY_TOKEN")

    master_key = derive_sidecar_master_key(device_key_file)
    api_url = f"http://{host}:{api_port}/api/v1/inspect/tool"
    return api_url, token, master_key


def load_bridge():
    bridge_path = ROOT_DIR / "mcp" / "workspace-admin-bridge.py"
    spec = importlib.util.spec_from_file_location("workspace_admin_bridge", bridge_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load MCP bridge from {bridge_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inspect(tool: str, args: dict) -> dict:
    api_url, sidecar_token, master_key = load_sidecar_settings()
    auth_candidates = []

    if sidecar_token:
        auth_candidates.append(sidecar_token)
    if master_key and master_key not in auth_candidates:
        auth_candidates.append(master_key)
    if not auth_candidates:
        auth_candidates.append("")

    last_response = None
    last_error = None

    for auth_token in auth_candidates:
        headers = {
            "Content-Type": "application/json",
            "X-DefenseClaw-Client": "openclaw-lab",
        }
        if auth_token:
            headers["Authorization"] = f"Bearer {auth_token}"

        try:
            response = requests.post(
                api_url,
                headers=headers,
                json={"tool": tool, "args": args},
                timeout=10,
            )
        except requests.RequestException as exc:
            raise SystemExit(
                "DefenseClaw sidecar API is not reachable. "
                "Run ./scripts/configure_defenseclaw.sh or restart defenseclaw-gateway, "
                f"then retry. url={api_url} error={exc}"
            ) from exc

        if response.status_code != 401:
            response.raise_for_status()
            return response.json()

        last_response = response
        last_error = response.text.strip()

    if last_response is not None:
        raise SystemExit(
            "DefenseClaw sidecar API rejected tool inspection auth. "
            "Run ./scripts/configure_defenseclaw.sh to refresh the local DefenseClaw wiring, "
            "or verify ~/.defenseclaw/.env contains OPENCLAW_GATEWAY_TOKEN. "
            f"url={api_url} status={last_response.status_code} body={last_error}"
        )

    raise SystemExit(
        "DefenseClaw sidecar API did not return a usable inspection result. "
        "Run ./scripts/configure_defenseclaw.sh or restart defenseclaw-gateway, "
        f"then retry. url={api_url}"
    )


def run_single_tool_case(bridge, *, case_name: str, tool: str, args: dict, executor) -> dict:
    verdict = inspect(tool, args)
    payload = {
        "case": case_name,
        "tool": tool,
        "args": args,
        "inspect": verdict,
        "executed": False,
    }
    if verdict.get("action") != "block":
        payload["executed"] = True
        payload["result"] = executor()
    return payload


def main() -> None:
    bridge = load_bridge()
    aws_path = ROOT_DIR / ".demo-state" / "fake-home" / ".aws" / "credentials"
    rce_marker = ROOT_DIR / "reports" / "mcp-rce-demo.txt"
    case_name = sys.argv[1] if len(sys.argv) > 1 else "full-replay"

    if case_name == "secret-read":
        payload = run_single_tool_case(
            bridge,
            case_name="secret-read",
            tool="read_runtime_config",
            args={"path": str(aws_path)},
            executor=lambda: json.loads(bridge.read_runtime_config(str(aws_path))),
        )
        report_path = ROOT_DIR / "reports" / "guarded-mcp-demo.json"
        report_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, indent=2))
        return

    if case_name == "expression-eval":
        expr = (
            f"(__import__('pathlib').Path({str(rce_marker)!r}).write_text("
            f"'score_template_expression executed arbitrary code\\n'), 7)[1]"
        )
        payload = run_single_tool_case(
            bridge,
            case_name="expression-eval",
            tool="score_template_expression",
            args={"expression": expr},
            executor=lambda: json.loads(bridge.score_template_expression(expr)),
        )
        report_path = ROOT_DIR / "reports" / "guarded-mcp-demo.json"
        report_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, indent=2))
        return

    if case_name == "shell-command":
        shell_cmd = "cat /etc/passwd | head -n 5"
        payload = run_single_tool_case(
            bridge,
            case_name="shell-command",
            tool="collect_support_bundle",
            args={"shell_cmd": shell_cmd},
            executor=lambda: json.loads(bridge.collect_support_bundle(shell_cmd)),
        )
        report_path = ROOT_DIR / "reports" / "guarded-mcp-demo.json"
        report_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, indent=2))
        return

    if case_name == "internal-fetch":
        url = "http://127.0.0.1:2019/config/"
        payload = run_single_tool_case(
            bridge,
            case_name="internal-fetch",
            tool="sync_partner_manifest",
            args={"url": url},
            executor=lambda: json.loads(bridge.sync_partner_manifest(url)),
        )
        report_path = ROOT_DIR / "reports" / "guarded-mcp-demo.json"
        report_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(payload, indent=2))
        return

    if case_name != "full-replay":
        raise SystemExit(f"Unsupported guarded MCP case: {case_name}")

    results: dict[str, object] = {}

    read_args = {"path": str(aws_path)}
    read_verdict = inspect("read_runtime_config", read_args)
    results["read_runtime_config"] = {
        "inspect": read_verdict,
        "executed": False,
    }
    if read_verdict.get("action") != "block":
        results["read_runtime_config"]["executed"] = True
        results["read_runtime_config"]["result"] = json.loads(
            bridge.read_runtime_config(str(aws_path))
        )

    expr = (
        f"(__import__('pathlib').Path({str(rce_marker)!r}).write_text("
        f"'score_template_expression executed arbitrary code\\n'), 7)[1]"
    )
    expr_args = {"expression": expr}
    expr_verdict = inspect("score_template_expression", expr_args)
    results["score_template_expression"] = {
        "inspect": expr_verdict,
        "executed": False,
    }
    if expr_verdict.get("action") != "block":
        results["score_template_expression"]["executed"] = True
        results["score_template_expression"]["result"] = json.loads(
            bridge.score_template_expression(expr)
        )

    report_path = ROOT_DIR / "reports" / "guarded-mcp-demo.json"
    report_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
