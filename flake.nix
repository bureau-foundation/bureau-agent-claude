# Copyright 2026 The Bureau Authors
# SPDX-License-Identifier: Apache-2.0

# Claude Code agent template for Bureau. Composes the Bureau agent
# driver wrapper (bureau-agent-claude) with the Claude Code CLI and
# developer tooling into a single sandbox environment.
#
# The bureau-agent-claude binary lives in the Bureau monorepo and
# manages the full agent lifecycle: spawning Claude Code with
# stream-json output, writing .claude/settings.local.json for hooks
# and MCP, parsing events into the Bureau agent driver pipeline, and
# persisting DriverSessionID for --resume across sandbox cycles.
#
# This flake owns the template definition and environment composition.
# The binary will migrate here once the Go SDK is extracted.
{
  description = "Claude Code agent template for Bureau sandboxes";

  nixConfig = {
    extra-substituters = [ "https://cache.infra.bureau.foundation" ];
    extra-trusted-public-keys = [
      "cache.infra.bureau.foundation-1:3hpghLePqloLp0qMpkgPy/i0gKiL/Sxl2dY8EHZgOeY= cache.infra.bureau.foundation-2:e1rDOXBK+uLDTT+YU2UzIzkNHpLEaG2jCHZumlH1UmY="
    ];
  };

  inputs = {
    bureau.url = "github:bureau-foundation/bureau";
    # Follow Bureau's nixpkgs pin to prevent version skew in shared
    # dependencies (glibc, git, openssl, etc.). Claude Code comes from
    # this same nixpkgs — to bump it independently, override the
    # claude-code package rather than breaking the follows.
    nixpkgs.follows = "bureau/nixpkgs";
    flake-utils.follows = "bureau/flake-utils";
  };

  outputs =
    {
      self,
      bureau,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
        };

        # Bureau agent driver wrapper — manages Claude Code lifecycle
        # within the Bureau event pipeline.
        agentClaude = bureau.packages.${system}.bureau-agent-claude;

        # Bureau CLI — launched as an MCP server subprocess by Claude
        # Code for Bureau tool access (tickets, artifacts, observation).
        bureauCli = bureau.packages.${system}.bureau;

        # Composed sandbox environment. Everything a Claude Code agent
        # needs: the driver wrapper, Claude Code CLI, Bureau CLI for
        # MCP, developer tools (git, gh), and language runtimes (node,
        # python for tool use within sandboxed projects).
        agentEnvironment = pkgs.buildEnv {
          name = "bureau-agent-claude-env";
          paths =
            [
              agentClaude
              bureauCli
              pkgs.claude-code
            ]
            ++ bureau.lib.bureauRuntime pkgs
            ++ [ bureau.packages.${system}.bureau-sandbox-env ]
            ++ bureau.lib.presets.developer pkgs
            ++ bureau.lib.applyModules bureau.lib.modules.runtime pkgs;
        };
      in
      {
        packages.default = agentEnvironment;

        # Bureau template definition. Published to Matrix via:
        #   bureau template publish --flake github:bureau-foundation/bureau-agent-claude
        #
        # Field names use snake_case matching TemplateContent JSON wire
        # format (lib/schema/events_template.go in Bureau).
        #
        # Inherits from bureau-agent, which provides:
        #   - agent-base: proxy socket, MACHINE_NAME, SERVER_NAME env vars
        #   - base-networked: host network, DNS, SSL
        #   - base: namespace isolation, security defaults, /tmp
        #   - required_services: ["agent", "artifact"]
        bureauTemplate = {
          description = "Claude Code agent with Bureau sandbox, MCP integration, and session persistence";
          inherits = [ "bureau/template:bureau-agent" ];
          command = [ "${agentClaude}/bin/bureau-agent-claude" ];
          environment = "${agentEnvironment}";
        };
      }
    );
}
