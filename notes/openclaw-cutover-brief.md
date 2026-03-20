# OpenClaw Cutover Brief

- The existing OpenClaw workspace has one home-grown skill and one custom MCP bridge.
- The migration window is 30 minutes, so the first ZeroClaw check must be quick and obvious.
- The operations team wants a reply that proves the agent is live before any extensions are trusted.
- Any extension that reads local configs, packages workspace files, or reaches outside the lab needs review first.
