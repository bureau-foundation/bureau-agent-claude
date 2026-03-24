# Agent Guide

This is a Nix flake that provides non-Bureau tools for Claude Code agent
sandboxes. Bureau platform binaries are provided separately by the daemon.
There is no Go code — the driver binary lives in Bureau's monorepo (for now).

## Repository structure

- `flake.nix` — tool composition and template definition. Exports
  `packages.default` (tools buildEnv) and `bureauTemplate` (Bureau template).
- `.github/workflows/ci.yaml` — builds the flake, validates the template
  output, and pushes to the R2 binary cache on merge to main.
- `README.md` — deployment guide for operators.

## Key design decision

This flake depends on Bureau only for `lib.presets` and `lib.modules` (pure
functions over nixpkgs that define tool groupings). It does NOT reference
`bureau.packages.*`. Bureau binaries are injected into sandboxes by the
daemon via `bureau-sandbox-env` PATH prepending.

This means Claude Code version bumps (via nixpkgs) don't require a Bureau
rebuild, and Bureau releases don't require updating this repo.

## Making changes

Edit `flake.nix`. Run `nix build` to verify, and
`nix eval --json .#bureauTemplate.x86_64-linux` to inspect the template.
Update `flake.lock` with `nix flake update` if changing inputs.

The `bureauTemplate` output must use snake_case field names matching Bureau's
`TemplateContent` JSON wire format. See `lib/schema/events_template.go`.
