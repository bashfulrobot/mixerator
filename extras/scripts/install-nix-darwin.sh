#!/usr/bin/env bash
#
# Build and activate the nix-darwin configuration for this host.
#
# Two paths, because the first switch is special: `darwin-rebuild` does not
# exist until nix-darwin has activated once, so the first run borrows it from
# the flake via `nix run`. Afterwards the installed binary is used, matching
# what `just rebuild` does.
#
# Prerequisites: Determinate Nix, Homebrew, the repo cloned, and working SSH
# auth to GitHub (the flake has a private git+ssh input -- see the preflight in
# bootstrap.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_macos

step "nix-darwin"

load_nix_env || die "nix is not on PATH. Run install-determinate.sh first."

[ -d "$REPO_DIR" ] || die "Repo not found at $REPO_DIR. Clone it first."
cd "$REPO_DIR"
[ -f flake.nix ] || die "No flake.nix in $REPO_DIR -- is that really the repo?"

host="$(target_hostname)"
flake_ref=".#$host"

if ! nix eval --raw ".#darwinConfigurations.$host.system.build.toplevel.drvPath" >/dev/null 2>&1; then
  err "No darwinConfigurations entry for this host: $host"
  detail "flake.nix currently defines:"
  nix eval --json '.#darwinConfigurations' --apply builtins.attrNames 2>/dev/null \
    | tr -d '[]"' | tr ',' '\n' | sed 's/^/      /' || true
  detail "Add a mkHost entry for $host in flake.nix, or rename the host to match."
  exit 1
fi

info "Host:  $host"
info "Flake: $flake_ref"
detail "The first switch takes a while -- it builds the whole system closure."

if ! confirm "Build and activate now?"; then
  die "Declined."
fi

# Prime the sudo timestamp up front so the password prompt is not buried in
# build output, same reasoning as the justfile's rebuild recipe.
sudo -v || die "sudo is required to activate a nix-darwin system."

if have darwin-rebuild; then
  info "Using the installed darwin-rebuild."
  sudo "$(command -v darwin-rebuild)" switch --flake "$flake_ref"
else
  info "First activation -- borrowing darwin-rebuild from the flake."
  sudo "$(command -v nix)" \
    --extra-experimental-features 'nix-command flakes' \
    run github:nix-darwin/nix-darwin#darwin-rebuild -- switch --flake "$flake_ref"
fi

ok "nix-darwin activated"
detail "Open a new terminal to pick up the new PATH and shell."
detail "From now on use 'just rebuild' (or 'just qr') instead of this script."
