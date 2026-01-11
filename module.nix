{ self, anthropic-skills, claude-plugins-official, tgnotify }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.claude-config;
  system = pkgs.stdenv.hostPlatform.system;

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
    permissions = {
      allow = defaultPermissions ++ cfg.extraPermissions;
    };
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
  codeSimplifierAgentPath = "${claude-plugins-official}/plugins/code-simplifier/agents/code-simplifier.md";

  # Go skills plugin for ccgo command
  goSkillsPluginPath = "${srcPath}/go-skills-plugin";

  # Create ccgo wrapper script that loads Go skills plugin
  ccgoScript = pkgs.writeShellScriptBin "ccgo" ''
    exec claude --plugin-dir ${goSkillsPluginPath} "$@"
  '';

in {
  options.programs.claude-config = {
    enable = lib.mkEnableOption "Claude Code configuration";

    extraPermissions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional permissions to add to Claude Code settings";
      example = [ "Edit" "Write" ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Add ccgo command to PATH
    home.packages = [ ccgoScript ];

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

    # Agents - code-simplifier from Anthropic's official plugins repo
    home.file.".claude/agents/code-simplifier.md".source = codeSimplifierAgentPath;
  };
}
