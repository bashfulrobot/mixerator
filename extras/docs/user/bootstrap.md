# Bootstrapping a fresh Mac

End-to-end setup for a machine with nothing on it. Scripts live in
`extras/scripts/`; this page is the narrative version.

## Before you start

1Password must be **installed, signed in, unlocked, and have its SSH agent
enabled** (*Settings → Developer → Use the SSH agent*, then *Configure SSH
agent*). This is a hard gate, and for a less obvious reason than "you need to
clone the repo" — see [Why 1Password is load-bearing](#why-1password-is-load-bearing).

## Run it

```bash
# from a fresh machine, once git is available
git clone git@github.com:bashfulrobot/mixerator.git ~/git/mixerator
cd ~/git/mixerator
./extras/scripts/bootstrap.sh
```

It prompts before each step and skips anything already done, so it is safe to
re-run after a failure. `MIXERATOR_YES=1` accepts every prompt for an unattended
run.

## What happens, in order

| # | Step | Why here |
| --- | --- | --- |
| 1 | Preflight | 1Password, GitHub SSH, Xcode CLT — fail fast |
| 2 | Determinate Nix | everything downstream needs `nix` |
| 3 | Homebrew | `homebrew.casks` drives an existing `brew`; activation fails without it |
| 4 | Clone into `~/git/mixerator` | the flake must be on disk to build from |
| 5 | nix-darwin switch | first run borrows `darwin-rebuild` from the flake |
| 6 | Claude Code | optional, deliberately not Nix-managed |

Step 5 is the long one — it builds the whole system closure.

## Shell environment: ignore what the installers tell you

Both the Homebrew and Claude Code installers end by telling you to append a line
to `~/.zprofile` or `~/.zshrc`. **Don't.** This repo declares those PATH entries
in Nix:

| Path | Declared in |
| --- | --- |
| `/opt/homebrew/bin` | `modules/system/homebrew/default.nix` |
| `~/.local/bin` | `modules/apps/cli/claude-code/default.nix` |

Both land on `environment.systemPath`, so nix-darwin wires them into every shell
it manages. A hand-edited dotfile duplicates the entry and creates exactly the
machine-local state the repo exists to eliminate.

Determinate Nix is different and fine: its installer patches `/etc/zshrc` and
`/etc/bashrc`, which are system files, not your dotfiles.

### Why the run doesn't need a restart mid-way

Newly installed tools aren't on the PATH of the shell that installed them. The
scripts work around this in-process — `load_nix_env` sources the Nix daemon
profile and `load_brew_env` runs `brew shellenv` (both in
`extras/scripts/lib/common.sh`) — so each step can see what the previous one
installed without you reopening anything.

That fix is scoped to the bootstrap run. **Your terminal is still stale when it
finishes**, so open a new one before doing anything else. Terminals that were
already open when you started will not see Nix, Homebrew, or your new shell
until reopened.

## Why 1Password is load-bearing

Two independent reasons, and the second is the one that bites:

- **`~/.ssh/config` is not managed by this repo.** Nothing in `modules/` writes
  it — 1Password's *Configure SSH agent* button does. Without its
  `IdentityAgent` line, `ssh` never reaches the agent and your keys are
  invisible.
- **`flake.nix` has a private input.** `inputs.upsight` is
  `git+ssh://git@github.com/bashfulrobot/upsight`, a private repo. Nix has to
  fetch it to *evaluate* the flake at all, so SSH auth must work before the
  first build. It is a prerequisite of the build, not something the build sets
  up for you.

Preflight therefore hard-fails on `ssh -T git@github.com` rather than warning.

## After bootstrap

Use `just`, not the scripts:

```
just rebuild     # or: just qr  (quiet, logs to /tmp/mixerator-rebuild.log)
```

Upgrades are user-initiated: `just upgrade` / `just qu`.

## Troubleshooting

**"Cannot authenticate to GitHub over SSH"** — 1Password locked, SSH agent
disabled, or the key isn't on your GitHub account. Check `ssh -T git@github.com`
by hand; it should say *"successfully authenticated"* and exit 1.

**"No darwinConfigurations entry for this host"** — `flake.nix` keys hosts by
`scutil --get LocalHostName`. Either add a `mkHost` entry for the new name or
set the hostname to match.

**Nix installed but not Determinate** — `install-determinate.sh` refuses to
install over a non-Determinate Nix. The flake uses the `determinate` module,
which expects `/etc/nix/nix.custom.conf`. Uninstall the existing Nix first.
