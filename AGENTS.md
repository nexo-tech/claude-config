# AGENTS.md

Purpose: Guidance for agentic coding in this repo.
Keep changes focused on Nix config, commands, and skill docs.

## Repository Layout
- `flake.nix` - Flake inputs and outputs.
- `flake.lock` - Locked flake dependencies.
- `module.nix` - Home Manager module for Claude config.
- `commands/` - Slash command markdown (frontmatter + docs).
- `go-skills-plugin/` - Plugin with curated skill markdown.
- `go-skills-plugin/skills/*/skill.md` - Individual skill docs.

## Build / Lint / Test Commands
This repo is mostly configuration and markdown; no dedicated test runner.
Use these commands as available in a Nix environment:
- `nix flake show` - Inspect available outputs.
- `nix flake check` - Run flake checks (currently minimal).
- `nix build` - Build default outputs if added later.
- `nix eval .#homeManagerModules.default` - Evaluate the module.

### Single-Test Guidance
- There is no unit test harness today.
- If checks are added, prefer `nix flake check -L` and narrow via flake checks.
- Document new single-test commands here when introduced.

## Coding Style: Nix
- Indentation: 2 spaces, no tabs.
- Keep braces on the same line as `let`, `in`, `{`, and function args.
- Use blank lines to separate logical sections.
- Prefer `inherit` for passing multiple attributes.
- Keep attribute sets ordered: inputs, locals, outputs.
- Use `lib.mkIf`/`lib.mkOption`/`lib.mkEnableOption` patterns as in `module.nix`.
- Use double quotes for strings.
- Keep list items one per line; align comments with two spaces before `#`.
- Avoid trailing whitespace.

### Nix Imports and Composition
- Keep `inputs` in `flake.nix` grouped and commented.
- Use `let` bindings for computed paths and derived values.
- Prefer `pkgs.writeText`/`pkgs.writeShellScriptBin` for generated files.
- Avoid inlining long JSON; use `builtins.toJSON`.

### Nix Error Handling
- Use clear error messages in `lib.mkOption` docs.
- Prefer `lib.mkIf` guards instead of deeply nested conditionals.
- When adding hooks or commands, verify paths exist or are derivations.

## Coding Style: Markdown (Commands and Skills)
- Use YAML frontmatter at top of `commands/*.md` and `skill.md`.
- Keep frontmatter keys lowercase and ordered: name/description/allowed-tools.
- One blank line between frontmatter and content.
- Use `#` for title, `##` for sections, `###` for subsections.
- Keep line lengths reasonable (≤ 100) when editing prose.
- Prefer fenced code blocks with language tags (` ```nix`, ` ```bash`).
- Use lists for steps and options; avoid dense paragraphs.
- Maintain existing section ordering unless instructed.

## Naming Conventions
- Files and directories use kebab-case (`go-htmx-sse`).
- Nix variables use lowerCamelCase for local bindings.
- Keep option names under `programs.claude-config` consistent and descriptive.
- For new commands, use short, action-oriented filenames.

## Imports and Dependencies
- Do not add new flake inputs unless necessary.
- If adding inputs, mirror the existing style and add comments.
- Prefer `inputs.<name>.follows = "nixpkgs"` when appropriate.

## Formatting and Tooling
- No formatter is configured; keep manual formatting consistent.
- If adding a formatter, document it here and update `flake.nix`.
- Avoid automated reflows that change markdown structure.

## Error Handling and Safety
- Avoid destructive actions; respect current permissions model.
- If adding shell scripts, use `set -euo pipefail` when appropriate.
- For hooks, keep commands deterministic and non-interactive.

## Agent Workflow Expectations
- Read existing files before editing.
- Keep changes minimal and scoped to the requested task.
- Avoid refactors unless requested.
- Update documentation when behavior changes.

## Common Tasks
- Updating default permissions: edit `module.nix`.
- Adding a command: create or update `commands/<name>.md`.
- Adding a skill: add under `go-skills-plugin/skills/<name>/skill.md`.
- Adding a new plugin: update `go-skills-plugin` and document in README.

## Notes on go-skills-plugin
- Skill files are long-form reference docs; keep structure intact.
- Prefer incremental edits with clear headings.
- When adding code samples, ensure they compile or are clearly illustrative.

## Cursor / Copilot Rules
- No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` found.
- If such rules are added later, mirror them here.

## Examples (Nix)
- Good:
- `home.file.".claude/settings.json".source = pkgs.writeText "claude-settings.json" settingsJson;`
- `home.file.".claude/commands/reflect.md".source = "${srcPath}/commands/reflect.md";`
- Avoid:
- Large inline JSON literals in `module.nix`.
- Unscoped permissions changes without updating README.

## Examples (Markdown)
- Good: short intro, clear sections, fenced code blocks.
- Avoid: missing frontmatter or inconsistent section levels.

## Testing Philosophy
- Prefer `nix flake check` as a smoke test.
- If adding checks, ensure they run in CI-friendly, non-interactive mode.

## Documentation Expectations
- Update `README.md` when behavior changes or new options are added.
- Mention new commands or skills in `README.md` if user-facing.

## File Ownership
- `flake.nix` and `module.nix` define module behavior.
- `commands/` is user-facing CLI behavior for Claude Code.
- `go-skills-plugin/` contains skill content; keep it curated.

## Commit Guidance (if asked)
- Keep messages short and descriptive.
- Mention config/skills/commands in the subject line as appropriate.

## Troubleshooting
- If `nix flake check` fails, run with `-L` for logs.
- Use `nix eval` to inspect module outputs.

## Security / Secrets
- Do not add secrets or API keys.
- Avoid hard-coding user paths outside `~/`.

## Final Reminder
- Preserve existing formatting and structure.
- Prefer clarity over cleverness.
- Ask the user when commands/tests are unclear.

## Line Count Target
- This file is intentionally verbose (~150 lines) for agent clarity.
- Keep updates in the same spirit and format.

## End
- Thank you for keeping this repo tidy.
- Happy hacking.
