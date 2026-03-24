# Copyright 2026 The Bureau Authors
# SPDX-License-Identifier: Apache-2.0

# Claude Code agent template for Bureau. Provides the non-Bureau
# tools that a Claude Code agent needs inside its sandbox: the
# Claude Code CLI, developer tools (git, gh), and language runtimes.
#
# Bureau platform binaries (bureau-agent-claude, bureau CLI, etc.)
# are provided by the daemon via bureau-sandbox-env — they are NOT
# included here. This flake has no Bureau *package* dependency and
# can be updated independently (e.g., to bump Claude Code version).
# Bureau is an input only for lib.presets and lib.modules (pure
# functions over nixpkgs that define tool groupings).
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

        # Agent tools: everything a Claude Code agent needs beyond
        # Bureau's own platform binaries (which the daemon provides
        # via bureau-sandbox-env PATH injection).
        #
        # Uses Bureau's preset/module system for tool groupings —
        # these are pure functions over nixpkgs, not Bureau packages.
        agentTools = pkgs.buildEnv {
          name = "bureau-agent-claude-tools";
          paths =
            [ pkgs.claude-code ]
            ++ bureau.lib.presets.developer pkgs
            ++ bureau.lib.applyModules bureau.lib.modules.runtime pkgs;
        };
      in
      {
        packages.default = agentTools;

        # Bureau template definition. Published to Matrix via:
        #   bureau template publish --flake github:bureau-foundation/bureau-agent-claude
        #
        # Field names use snake_case matching TemplateContent JSON wire
        # format (lib/schema/events_template.go in Bureau).
        #
        # Inherits from agent-base, which provides:
        #   - base-networked: host network, DNS, SSL
        #   - base: namespace isolation, security defaults, /tmp
        #   - Proxy socket, MACHINE_NAME, SERVER_NAME env vars
        #
        # The command uses a bare name — the daemon resolves it from
        # bureau-sandbox-env on PATH. The environment field provides
        # this flake's tools; the daemon prepends sandbox-env/bin
        # so Bureau binaries are also available.
        bureauTemplate = {
          description = "Claude Code agent with Bureau sandbox, MCP integration, and session persistence";
          inherits = [ "bureau/template:agent-base" ];
          command = [ "bureau-agent-claude" ];
          environment = "${agentTools}";
          required_services = [
            "agent"
            "artifact"
          ];
        };
      }
    );
}
