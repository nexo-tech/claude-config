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
    export OPENCODE_CONFIG="$HOME/.config/opencode-dev"
    exec opencode "$@"
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
    # Add ccgo and ocgo commands to PATH
    home.packages = [ ccgoScript ocgoScript ];

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

  };
}
