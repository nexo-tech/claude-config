{
  description = "Claude Code configuration flake - settings, commands, and skills";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Anthropic's official skills repository
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, anthropic-skills }: {
    homeManagerModules.default = import ./module.nix {
      inherit self anthropic-skills;
    };
  };
}
