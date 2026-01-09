{
  description = "Claude Code configuration flake - settings, commands, and skills";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

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
  };

  outputs = { self, nixpkgs, anthropic-skills, claude-plugins-official }: {
    homeManagerModules.default = import ./module.nix {
      inherit self anthropic-skills claude-plugins-official;
    };
  };
}
