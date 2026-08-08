# claude-code module

Nix-managed Claude Code configuration for macOS. A deliberately reduced port of
nixerator's `modules/apps/cli/claude-code`, which is ~12 MB across 40+ files and
carries a lot of NixOS-only machinery.

## What this manages

| Path | Owner | Notes |
| --- | --- | --- |
| `~/.claude/settings.json` | Nix (declared keys) + runtime (the rest) | deep-merged at activation, Nix side wins |
| `~/.claude/CLAUDE.md` | Nix | copied writable |
| `~/.claude/agents/*.md` | Nix, capture-able | copied writable |
| `~/.claude/output-styles/*.md` | Nix, capture-able | copied writable |
| `~/.local/bin/claude` (native installer) | Nix bootstraps, then hands off | see below |

Everything else under `~/.claude` (sessions, projects, caches, shell-snapshots,
file-history, plugins/marketplaces) is runtime state and is left alone.

## Why files are copied, not symlinked

Claude Code **writes to its own config while you work** — `theme`,
`enabledPlugins`, `skillOverrides` all land in `settings.json` at runtime. The
usual home-manager approach of symlinking into the Nix store would make the file
read-only and break those writes.

So activation copies (via GNU `cp --no-preserve=mode`; macOS `cp` is BSD and has
no such flag) and `claude-capture` reconciles the two sides afterwards against a
SHA snapshot in `config/.capture-state.json`.

```
just capture-dry     # what would change, both directions
just capture         # apply, then review the git diff
```

The first run has no snapshot and will need `just capture --bootstrap`.

## Install method: native installer, not Homebrew

Claude Code is installed via Anthropic's native installer
(`curl -fsSL https://claude.ai/install.sh | bash`), triggered once by a
home-manager activation script guarded on `~/.local/bin/claude` not already
existing. It is deliberately **not** the Homebrew cask this module used
before: a Homebrew- or Nix-managed binary's path/identity changes on every
update, which was colliding with macOS Keychain ACLs (each new binary looked
like a different app to Keychain) and with PATH resolution when multiple
install methods coexisted. See `claude-fix.md` at the repo root for the full
diagnosis.

The native installer manages its own launcher symlink at `~/.local/bin/claude`
into `~/.local/share/claude/versions/` and self-updates in the background from
there -- Nix's job is only the first bootstrap. `environment.systemPath` in
this module puts `~/.local/bin` on `PATH`. If you previously had the
`claude-code`/`claude-code@latest` Homebrew cask installed, uninstall it
(`brew uninstall --cask claude-code@latest`) so only one install method is on
PATH at a time.

## Deliberately NOT ported from nixerator

- `build/` — Kubernetes and flux-operator MCP servers, both Linux-targeted.
- `cfg/mcp-servers.nix` — needs a kubeconfig and Kong-internal endpoints.
- The hook suite (`auto-gate`, `precompact`, `reinject`, `git-sync`, the
  `guard-*` scripts) — these are the largest and most valuable part of the
  nixerator module and are worth porting next, but each one is a shell script
  plus a `jq` injection clause in activation.
- Skills and the declarative plugin/marketplace surface
  (`cfg/plugin-config.nix`, `cfg/skill-defaults.nix`).
- `statusline.sh`.
- `capture-resolve` — nixerator exposes it as a fish function that rewrites the
  snapshot to pick a winning side. `capture-sync.py` still *reports* conflicts
  here; resolving one currently means editing `.capture-state.json` by hand.

## Adaptations made to the ported config

- `settings.json`: `nixos-rebuild` permissions became `darwin-rebuild`;
  Linux-only tools (`hyprctl`, `systemctl`, `journalctl`, `lsblk`, `dmesg`,
  `ip`, `ss`, `xdg-open`, `notify-send`) dropped; macOS equivalents added
  (`scutil`, `sw_vers`, `defaults read`, `pkgutil`, `codesign`, `launchctl`,
  `system_profiler`, read-only `brew`). Mutating `brew` verbs are denied.
- `settings.json`: `SSH_AUTH_SOCK` points at the 1Password agent socket rather
  than the gcr socket used on the NixOS hosts.
- `CLAUDE.md`: rules depending on Linux-only machinery (the Hyprland
  `text-polish` keybind, `rtk`, `send-to-dustin`/wayland) dropped rather than
  carried over dead; `/home/dustin/...` doc paths replaced with repo-relative
  references. A section on MDM constraints on this machine was added.
- `agents/` and `output-styles/compact.md` were copied verbatim.

## Status

**Unevaluated.** Written before Nix was installed on this machine; nothing here
has been through a `darwin-rebuild`.
