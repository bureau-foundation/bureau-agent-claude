# Agent Guide

This is a Nix flake that composes Bureau's `bureau-agent-claude` driver
wrapper with the Claude Code CLI and developer tooling, then exports the
result as a Bureau template. There is no Go code here (yet — the driver
binary will migrate from Bureau once the Go SDK is extracted).

## Repository structure

- `flake.nix` — environment composition and template definition. Exports
  `packages.default` (composed buildEnv) and `bureauTemplate` (Bureau
  template attributes).
- `.github/workflows/ci.yaml` — builds the flake, validates the template
  output, and pushes to the R2 binary cache on merge to main.
- `README.md` — deployment guide for operators.

## Making changes

Edit `flake.nix`. Run `nix build` to verify it builds, and
`nix eval --json .#bureauTemplate.x86_64-linux` to verify the template output.
Update `flake.lock` with `nix flake update` if changing inputs.

The `bureauTemplate` output must use snake_case field names matching Bureau's
`TemplateContent` JSON wire format. See the Bureau monorepo's
`lib/schema/events_template.go` for the full field list.

## Key dependencies

- **Bureau** (`bureau` input) — provides `bureau-agent-claude` binary,
  `bureau` CLI, runtime modules (presets, modules), and `bureauRuntime`
- **nixpkgs** (follows Bureau's pin) — provides `claude-code`, `git`, `gh`,
  `nodejs`, `python3`, and standard Unix tools

To add packages to the sandbox environment, add them to the `paths` list in
the `agentEnvironment` buildEnv definition in `flake.nix`.
