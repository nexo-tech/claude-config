{
  description = "Claude Code configuration flake - settings, commands, and skills";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: {
    homeManagerModules.default = import ./module.nix { inherit self; };
  };
}
