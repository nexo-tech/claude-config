# claude-config

Nix flake for managing Claude Code configuration across machines. Because your AI assistant deserves a proper dotfiles setup too.

## What's inside

- **Settings** - Sensible default permissions, disabled attribution, macOS notification hooks
- **Commands** - Custom slash commands (`/reflect` for session notes)
- **Skills** - Global skills fetched from [Anthropic's official skills repo](https://github.com/anthropics/skills) (includes `skill-creator` with all scripts)

## Usage

Add to your flake inputs:

```nix
{
  inputs.claude-config = {
    url = "github:nexo-tech/claude-config";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Import in your Home Manager config:

```nix
{
  imports = [ inputs.claude-config.homeManagerModules.default ];
  programs.claude-config.enable = true;
}
```

### Options

```nix
{
  programs.claude-config = {
    enable = true;
    extraPermissions = [ "Edit" "Write" ];  # Add more permissions
  };
}
```

## What gets installed

| Path | Description |
|------|-------------|
| `~/.claude/settings.json` | Permissions, hooks, attribution settings |
| `~/.claude/commands/` | Slash commands |
| `~/.claude/skills/` | Global skills |

## macOS Bonus

On Darwin, you get native notifications when Claude finishes a task or needs attention. No more staring at the terminal.
