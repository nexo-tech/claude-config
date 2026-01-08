{ self }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.claude-config;
  isDarwin = pkgs.stdenv.isDarwin;

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

  # macOS notification script
  notifyScript = pkgs.writeShellScriptBin "claude-notify" ''
    #!/bin/bash
    # Claude Code hooks - triggers macOS notifications
    HOOK_TYPE="$1"
    INPUT=$(cat)

    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id' | cut -c1-8)

    case "$HOOK_TYPE" in
      stop)
        TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
        MSG=""
        if [ -f "$TRANSCRIPT_PATH" ]; then
          MSG=$(tail -n 30 "$TRANSCRIPT_PATH" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -1 | tr '\n' ' ' | cut -c1-80)
        fi
        MSG=''${MSG:-"Task completed"}
        osascript -e "display notification \"$MSG\" with title \"Claude Code\" subtitle \"Done\" sound name \"Glass\""
        ;;
      notification)
        # Notification hook - permission requests and questions
        MSG=$(echo "$INPUT" | jq -r '.message // "Needs your attention"' | cut -c1-80)
        osascript -e "display notification \"$MSG\" with title \"Claude Code\" subtitle \"Action needed\" sound name \"Ping\""
        ;;
    esac
  '';

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
  } // lib.optionalAttrs isDarwin {
    hooks = {
      Stop = [{
        hooks = [{
          type = "command";
          command = "${notifyScript}/bin/claude-notify stop";
        }];
      }];
      Notification = [{
        hooks = [{
          type = "command";
          command = "${notifyScript}/bin/claude-notify notification";
        }];
      }];
    };
  });

  # Path to this flake's source
  srcPath = self;

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
    # Claude Code settings.json
    home.file.".claude/settings.json".source =
      pkgs.writeText "claude-settings.json" settingsJson;

    # Commands (slash commands)
    home.file.".claude/commands/reflect.md".source =
      "${srcPath}/commands/reflect.md";

    # Skills
    home.file.".claude/skills/skill-creator/SKILL.md".source =
      "${srcPath}/skills/skill-creator/SKILL.md";
  };
}
