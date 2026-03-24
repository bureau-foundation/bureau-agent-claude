# bureau-agent-claude

Claude Code agent template for [Bureau](https://github.com/bureau-foundation/bureau).
Runs Claude Code in a sandboxed environment with MCP integration, session
persistence across sandbox cycles, and full Bureau agent lifecycle management.

## What this provides

A Nix flake that composes the Bureau agent driver wrapper (`bureau-agent-claude`)
with the Claude Code CLI and developer tooling into a sandbox environment, then
exports it as a Bureau template.

The composed environment includes:

- **bureau-agent-claude** — Bureau agent driver wrapper (manages Claude Code
  lifecycle, event parsing, session state, checkpoint persistence)
- **claude-code** — Claude Code CLI (the AI coding assistant)
- **bureau** — Bureau CLI (launched as MCP server for Bureau tool access)
- **Developer tools** — git, gh, nano, Node.js, Python, and standard Unix tools

## Architecture

```
bureau-agent-claude (driver wrapper)
    │
    ├── Spawns: claude --output-format stream-json --print --verbose
    │   ├── Claude Code reads .claude/settings.local.json
    │   │   ├── Hooks → bureau-agent-claude hook <event>
    │   │   └── MCP servers → bureau mcp serve
    │   └── Produces stream-json events on stdout
    │
    ├── Parses events → Bureau agent driver pipeline
    │   ├── Session lifecycle (start/end via agent service socket)
    │   ├── Metrics aggregation (token counts, tool usage)
    │   └── Context checkpointing (CAS artifact store)
    │
    └── Session persistence
        ├── DriverSessionID → --resume <id> on next sandbox cycle
        └── .claude/ directory → persisted via artifact bindings
```

## Deployment

### 1. Publish the template

```bash
bureau template publish --flake github:bureau-foundation/bureau-agent-claude \
    --room <your-template-room>
```

### 2. Create a workspace with Claude agents

```bash
bureau workspace create my-project \
    --machine <machine> \
    --template bureau/template:bureau-agent-claude \
    --param repository=https://github.com/org/repo.git \
    --agent-count 3
```

Each agent gets its own sandbox with independent session state, checkpoint
chains, and resume capability. Session persistence survives sandbox restarts
(binary updates, environment transitions, manual restarts).

### 3. Observe

```bash
# Single agent
bureau observe agent/my-project/0

# All agents on this machine
bureau dashboard
```

## Updates

To update the template (after a Claude Code version bump in nixpkgs, or a
Bureau release with driver changes):

```bash
# In this repo: update inputs, rebuild
nix flake update
nix build

# Re-publish to the fleet
bureau template publish --flake github:bureau-foundation/bureau-agent-claude \
    --room <your-template-room>
```

The daemon detects the template change via /sync and restarts affected
sandboxes automatically, preserving session state through the cycle.

## Binary cache

This flake is configured to use Bureau's R2 binary cache at
`cache.infra.bureau.foundation`. CI pushes signed closures on every merge to
main, so `nix build` and `bureau template publish --flake` fetch pre-built
binaries rather than compiling from source.

## Development

```bash
# Build the composed environment
nix build

# Evaluate the template output
nix eval --json .#bureauTemplate.x86_64-linux | jq .

# Check what's in the environment
ls -la result/bin/
```

## License

Apache-2.0. See [LICENSE](LICENSE).
