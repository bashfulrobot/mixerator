# extras/scripts

Fresh-Mac bootstrap. These run **before** Nix exists, so they are plain bash
against macOS's system bash 3.2 — no associative arrays, no `mapfile`, nothing
from nixpkgs.

| Script | Does | Idempotent |
| --- | --- | --- |
| `bootstrap.sh` | Guided end-to-end run of everything below | yes |
| `install-determinate.sh` | Determinate Nix | skips if present |
| `install-homebrew.sh` | Homebrew | skips if present |
| `install-nix-darwin.sh` | First `darwin-rebuild switch` | re-runnable |
| `install-claude.sh` | Claude Code, native installer | skips unless `--force` |
| `lib/common.sh` | Shared prompts/logging, sourced not executed | — |

Each installer is standalone — run one on its own to repair a single piece.

## Usage

```bash
./extras/scripts/bootstrap.sh          # guided, prompts at each step
MIXERATOR_YES=1 ./extras/scripts/bootstrap.sh   # unattended
```

## Order, and why

1. **Preflight** — 1Password, GitHub SSH, Xcode CLT
2. **Determinate Nix** — everything downstream needs `nix`
3. **Homebrew** — `homebrew.casks` in nix-darwin *drives* an existing `brew`; it
   does not install it, and activation fails if it is missing
4. **Clone** into `~/git/mixerator` — the flake must be on disk to build from
5. **nix-darwin** — first switch borrows `darwin-rebuild` from the flake via
   `nix run`, since it does not exist until nix-darwin has activated once
6. **Claude Code** — optional, and deliberately not Nix-managed

## The 1Password dependency is load-bearing

1Password must be installed, unlocked, and have its SSH agent enabled before
step 1 passes. Two independent reasons:

- **`~/.ssh/config` is not managed by this repo.** Nothing in `modules/` writes
  it. 1Password's *Settings → Developer → Configure SSH agent* creates it, and
  without its `IdentityAgent` line `ssh` never reaches the agent.
- **`flake.nix` has a private input.** `inputs.upsight` is
  `git+ssh://git@github.com/bashfulrobot/upsight`, a private repo. Nix cannot
  *evaluate* the flake without SSH auth, so this has to work before the first
  build — it is not something the first build sets up for you.

That is why preflight hard-fails on `ssh -T git@github.com` rather than warning.

## After bootstrap

Use `just` from the repo, not these scripts:

```
just rebuild    # or: just qr
```
