{ self, anthropic-skills, claude-plugins-official, tgnotify, nixpkgs-unstable }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.claude-config;
  system = pkgs.stdenv.hostPlatform.system;

  # Unstable packages for OpenCode
  pkgs-unstable = import nixpkgs-unstable { inherit system; };

  # Default permissions for Claude Code
  defaultPermissions = [
    "Bash"
    "Read"
    "Grep"
    "Glob"
    "LS"
    "WebFetch"
    "WebSearch"
    "Task"
    "ExitPlanMode"
    "TodoWrite"
    "BashOutput"
    "KillBash"
    "WebFetch(domain:docs.anthropic.com)"
    "mcp__*"
  ];

  # tgnotify package for the current system
  tgnotifyPkg = tgnotify.packages.${system}.default;

  # Generate the settings JSON
  settingsJson = builtins.toJSON ({
    permissions = { allow = defaultPermissions ++ cfg.extraPermissions; };
    # Disable Claude attribution in git commits and PRs
    attribution = {
      commit = "";
      pr = "";
    };
    # Telegram notifications via tgnotify (cross-platform)
    hooks = {
      Stop = [{
        hooks = [{
          type = "command";
          command = "${tgnotifyPkg}/bin/tgnotify";
        }];
      }];
      Notification = [{
        hooks = [{
          type = "command";
          command = "${tgnotifyPkg}/bin/tgnotify";
        }];
      }];
    };
  });

  # Path to this flake's source
  srcPath = self;

  # Path to Anthropic's skill-creator
  skillCreatorPath = "${anthropic-skills}/skills/skill-creator";

  # Path to code-simplifier agent
  codeSimplifierAgentPath =
    "${claude-plugins-official}/plugins/code-simplifier/agents/code-simplifier.md";

  # Go skills plugin for ccgo/ocgo commands
  goSkillsPluginPath = "${srcPath}/go-skills-plugin";

  # Create ccgo wrapper script that loads Go skills plugin
  ccgoScript = pkgs.writeShellScriptBin "ccgo" ''
    exec claude --plugin-dir ${goSkillsPluginPath} "$@"
  '';

  # Create ocgo wrapper script that uses a custom OpenCode config
  ocgoScript = pkgs.writeShellScriptBin "ocgo" ''
    export OPENCODE_CONFIG="$HOME/.config/opencode-dev/opencode.json"
    export OPENCODE_CONFIG_DIR="$HOME/.config/opencode-dev"
    exec opencode "$@"
  '';

  # OpenCode configuration
  opencodeConfig = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "anthropic/claude-sonnet-4-5";
    permission = {
      edit = "allow";
      write = "allow";
      bash = "allow";
    };
  };

  # OpenCode tgnotify plugin
  opencodeTgnotifyPlugin = ''
    import { execSync } from "child_process";

    export const TgNotifyPlugin = async ({ project }) => ({
      event: async ({ event }) => {
        if (event.type === "session.idle" || event.type === "session.error") {
          const payload = JSON.stringify({
            hook_event_name: event.type === "session.idle" ? "Stop" : "Notification",
            cwd: project.path,
            message: event.type === "session.error" ? "Session error" : "",
            transcript_path: "",
            tool_name: "opencode"
          });
          try {
            execSync("${tgnotifyPkg}/bin/tgnotify", { input: payload, stdio: ["pipe", "inherit", "inherit"] });
          } catch {}
        }
      }
    });
  '';

in {
  options.programs.claude-config = {
    enable = lib.mkEnableOption "Claude Code configuration";

    extraPermissions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional permissions to add to Claude Code settings";
      example = [ "Edit" "Write" ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Add ccgo/ocgo commands and opencode to PATH
    home.packages = [ ccgoScript ocgoScript pkgs-unstable.opencode ];

    # Claude Code settings.json
    home.file.".claude/settings.json".source =
      pkgs.writeText "claude-settings.json" settingsJson;

    # Commands (slash commands)
    home.file.".claude/commands/reflect.md".source =
      "${srcPath}/commands/reflect.md";

    # Skills - skill-creator from Anthropic's official repo
    home.file.".claude/skills/skill-creator" = {
      source = skillCreatorPath;
      recursive = true;
    };

    # Go skills for OpenCode (custom config directory)
    home.file.".config/opencode-dev/skill" = {
      source = "${goSkillsPluginPath}/skills";
      recursive = true;
    };

    # Agents - code-simplifier from Anthropic's official plugins repo
    home.file.".claude/agents/code-simplifier.md".source =
      codeSimplifierAgentPath;

    # OpenCode configuration
    home.file.".config/opencode-dev/opencode.json".source =
      pkgs.writeText "opencode.json" opencodeConfig;

    # OpenCode agents - symlink Claude Code agents
    home.file.".config/opencode-dev/agent/code-simplifier.md".source =
      codeSimplifierAgentPath;

    # OpenCode tgnotify plugin
    home.file.".config/opencode-dev/plugin/tgnotify.ts".text =
      opencodeTgnotifyPlugin;
  };
}
