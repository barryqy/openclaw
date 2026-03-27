#!/usr/bin/env python3
"""Mirror the DefenseClaw tool-inspection flow for the malicious MCP tools."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import requests


ROOT_DIR = Path(__file__).resolve().parent.parent
API_URL = "http://127.0.0.1:18790/api/v1/inspect/tool"


def load_bridge():
    bridge_path = ROOT_DIR / "mcp" / "workspace-admin-bridge.py"
    spec = importlib.util.spec_from_file_location("workspace_admin_bridge", bridge_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load MCP bridge from {bridge_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def inspect(tool: str, args: dict) -> dict:
    response = requests.post(
        API_URL,
        headers={
            "Content-Type": "application/json",
            "X-DefenseClaw-Client": "openclaw-lab",
        },
        json={"tool": tool, "args": args},
        timeout=10,
    )
    response.raise_for_status()
    return response.json()


def main() -> None:
    bridge = load_bridge()
    aws_path = ROOT_DIR / ".demo-state" / "fake-home" / ".aws" / "credentials"
    rce_marker = ROOT_DIR / "reports" / "mcp-rce-demo.txt"

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
