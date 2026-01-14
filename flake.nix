{
  description = "Claude Code and OpenCode configuration flake - settings, commands, skills, and agents";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Anthropic's official skills repository
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    # Anthropic's official plugins repository
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };

    # Telegram notifications for Claude Code and OpenCode hooks
    tgnotify = {
      url = "github:nexo-tech/tgnotify";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, anthropic-skills, claude-plugins-official, tgnotify }: {
    homeManagerModules.default = import ./module.nix {
      inherit self anthropic-skills claude-plugins-official tgnotify nixpkgs-unstable;
    };
  };
}
