#!/usr/bin/env python3
"""
Safe MCP server used as the clean baseline for the OpenClaw lab.
"""

import json

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("safe-migration-reference")

CHECKLISTS = {
    "precheck": [
        "Confirm the ZeroClaw binary was built from the expected commit.",
        "Verify LLM_BASE_URL and LLM_API_KEY are present in the lab shell.",
        "Snapshot the current OpenClaw skills and MCP settings before the cutover.",
    ],
    "cutover": [
        "Create a clean ZeroClaw profile in a repo-local .zeroclaw directory.",
        "Run one short prompt to prove the model path is healthy.",
        "Install or wire extensions only after they have been reviewed.",
    ],
    "rollback": [
        "Remove untrusted extensions from the ZeroClaw profile.",
        "Restore the previous runtime config and confirm the old workflow still responds.",
        "Keep the scanner reports for the change ticket.",
    ],
}


@mcp.tool()
def get_cutover_checklist(stage: str) -> str:
    """Return a short migration checklist for precheck, cutover, or rollback."""
    stage_name = stage.strip().lower()
    if stage_name not in CHECKLISTS:
        return "Unknown stage. Use precheck, cutover, or rollback."

    return json.dumps({"stage": stage_name, "items": CHECKLISTS[stage_name]}, indent=2)


@mcp.tool()
def estimate_ticket_window(host_count: int, change_type: str = "rolling") -> str:
    """Estimate a simple migration window from the host count and change type."""
    if host_count < 1:
        return "Host count must be greater than zero."

    if change_type not in {"rolling", "full-stop"}:
        return "Change type must be rolling or full-stop."

    per_host = 6 if change_type == "rolling" else 10
    minutes = host_count * per_host
    summary = {
        "host_count": host_count,
        "change_type": change_type,
        "estimated_minutes": minutes,
    }
    return json.dumps(summary, indent=2)


@mcp.tool()
def search_runbooks(query: str, limit: int = 3) -> str:
    """Return a few canned runbook matches for a migration topic."""
    if not query.strip():
        return "Query is required."

    if limit < 1 or limit > 10:
        return "Limit must stay between 1 and 10."

    results = [
        {"title": f"{query} cutover checklist", "confidence": 0.95},
        {"title": f"{query} rollback steps", "confidence": 0.89},
        {"title": f"{query} validation notes", "confidence": 0.82},
    ]
    return json.dumps({"query": query, "results": results[:limit]}, indent=2)


if __name__ == "__main__":
    mcp.run()
