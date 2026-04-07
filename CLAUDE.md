# Mixerator

## Rules

- Never commit plaintext secrets; use `secrets/`.
- Avoid host-specific or machine-local paths; prefer `settings/globals.nix`.
- Use `nix fmt` and `statix` + `deadnix`.
- Never run `darwin-rebuild` directly or `git commit`/`git push` -- the user handles commits. After changes, suggest a conventional commit scope and title (e.g., `feat(fish): add zoxide integration`).
- When you need to test a darwin-rebuild during development, run `just quiet-rebuild` (alias `just qr`). This captures all build output to `/tmp/mixerator-rebuild.log` and keeps your context clean. On failure, spawn a Nix subagent to read the log, diagnose the error, and propose a fix. Do not read the log in the main context.
- Never run upgrades on your own. Upgrades are always user-initiated. If the user asks you to run an upgrade, use `just quiet-upgrade` (alias `just qu`). Same log-and-subagent pattern with `/tmp/mixerator-upgrade.log`.

## Docs (open only when needed)

Open these lazily when a relevant topic comes up. Do not read them all upfront.

**Core architecture:**

- `extras/docs/architecture.md` -- directory structure, flake organization, module system

## Module Conventions

- Modules auto-import via `modules/default.nix` -- never manually import a module elsewhere. Subdirs named `disabled/`, `build/`, `cfg/`, `reference/` are excluded from auto-import.
- Standard structure: `let cfg = config.NAMESPACE.PATH;` -> `options` with `lib.mkEnableOption` -> `config = lib.mkIf cfg.enable { ... }`.
- Namespace matches directory path: `apps.cli.*`, `apps.gui.*`, `suites.*`, `system.*`, `archetypes.*`.
- Home Manager config goes inside `home-manager.users.${globals.user.name} = { ... }`.
- Configuration priority: prefer `programs.<name>` or `services.<name>` Home Manager modules first, then nix-darwin options, then `home.file` as a last resort.
- Guard secrets access: `lib.optionalAttrs (secrets.foo or null != null) { ... }`.
- macOS system preferences use `system.defaults.*` in nix-darwin.
- Homebrew casks for GUI apps not available in nixpkgs use `homebrew.casks`.

## Tools

- To search nixpkgs unstable: `nix search github:NixOS/nixpkgs/nixpkgs-unstable#PACKAGE-NAME --json`
