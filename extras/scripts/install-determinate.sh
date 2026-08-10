#!/usr/bin/env bash
#
# Install Determinate Nix.
#
# This repo's flake consumes the `determinate` module, which stands nix-darwin's
# own Nix management down in favour of /etc/nix/nix.custom.conf -- so the
# Determinate installer, not the upstream one, is the supported way in.
#
# Idempotent: exits early if a Determinate install is already present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_macos

step "Determinate Nix"

if load_nix_env; then
  if have determinate-nixd || [ -e /etc/nix/nix.custom.conf ]; then
    skip "Determinate Nix already installed ($(nix --version 2>/dev/null || echo 'version unknown'))"
    exit 0
  fi
  warn "Nix is installed but does not look like Determinate:"
  detail "$(nix --version 2>/dev/null || echo 'nix --version failed')"
  detail "This repo's flake expects Determinate (it uses the determinate module)."
  detail "Uninstall the existing Nix first -- installing over it will not end well."
  die "Refusing to install on top of a non-Determinate Nix."
fi

info "Installs the Nix daemon, /nix, and the Determinate layer."
detail "Requires sudo. You will be prompted by the installer itself."
if ! confirm "Install Determinate Nix now?"; then
  die "Declined. Nix is required for everything downstream."
fi

curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix \
  | sh -s -- install --determinate

if ! load_nix_env; then
  err "Installer finished but 'nix' is still not on PATH."
  detail "Open a new terminal and re-run the bootstrap -- the daemon profile is"
  detail "only wired into shells started after installation."
  exit 1
fi
hash -r 2>/dev/null || true

ok "Determinate Nix installed ($(nix --version))"

# The installer edits /etc/zshrc and /etc/bashrc, not ~/.zshrc -- system files,
# so every new shell picks Nix up with no per-user edit. The current shell is
# stale, which load_nix_env has already worked around by sourcing the daemon
# profile directly, so the bootstrap can keep going in this terminal.
detail "Nix patched /etc/zshrc and /etc/bashrc (system-wide, not ~/.zshrc)."
detail "This run already sourced the daemon profile, so no restart is needed"
detail "to continue -- but existing terminals will not see nix until reopened."
