# bureau-agent-claude

Claude Code agent template for [Bureau](https://github.com/bureau-foundation/bureau).
Runs Claude Code in a sandboxed environment with MCP integration, session
persistence across sandbox cycles, and full Bureau agent lifecycle management.

## What this provides

A Nix flake that composes the non-Bureau tools a Claude Code agent needs:
the Claude Code CLI, developer tools (git, gh, node, python), and standard
Unix utilities. Bureau platform binaries (`bureau-agent-claude`, `bureau` CLI,
etc.) are provided by the daemon via `bureau-sandbox-env` PATH injection —
they are NOT included in this closure.

This means bumping Claude Code version requires updating this repo only,
not Bureau itself.

## Architecture

```
Daemon provides (via sandbox-env):        This repo provides (via environment):
  bureau-agent-claude                       claude (Claude Code CLI)
  bureau (CLI, MCP server)                  git, gh, node, python, bun
  bureau-proxy-call                         bash, coreutils, curl, openssl
  bureau-pipeline-executor                  and other developer tools
```

Both are composed into the sandbox's PATH by the launcher:
`sandbox-env/bin : template-environment/bin : /usr/local/bin:/usr/bin:/bin`

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

### 3. Observe

```bash
bureau observe agent/my-project/0
bureau dashboard
```

## Updates

To bump Claude Code version:

```bash
nix flake update     # Updates nixpkgs (which includes claude-code)
nix build            # Verify it builds
git add -A && git commit -m "Bump claude-code to X.Y.Z"
git push
```

Then re-publish the template. The daemon detects the template change via
/sync and restarts affected sandboxes, preserving session state.

## Binary cache

CI pushes signed closures to `cache.infra.bureau.foundation` on every merge
to main. `nix build` and `bureau template publish --flake` fetch pre-built
binaries from the cache.

## Development

```bash
nix build                                              # Build tools closure
nix eval --json .#bureauTemplate.x86_64-linux | jq .   # Inspect template
ls -la result/bin/                                      # See what's included
```

## License

Apache-2.0. See [LICENSE](LICENSE).
