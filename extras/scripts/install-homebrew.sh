#!/usr/bin/env bash
#
# Install Homebrew.
#
# nix-darwin's `homebrew.*` options (used here for GUI casks that are not in
# nixpkgs) only *declare* what should be installed -- they drive an existing
# `brew` binary and will fail the activation if Homebrew is absent. So this has
# to run before the first darwin-rebuild.
#
# Idempotent: exits early if brew is already installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_macos

step "Homebrew"

if load_brew_env; then
  skip "Homebrew already installed ($(brew --version 2>/dev/null | head -1))"
  exit 0
fi

info "nix-darwin's homebrew.casks options drive an existing brew binary;"
info "they do not install Homebrew themselves."
detail "The installer needs sudo and will also pull in the Xcode Command Line"
detail "Tools if they are missing. This can take several minutes."
if ! confirm "Install Homebrew now?"; then
  die "Declined. The first darwin-rebuild will fail without brew present."
fi

NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if ! load_brew_env; then
  die "Installer finished but 'brew' is still not on PATH."
fi
hash -r 2>/dev/null || true

ok "Homebrew installed ($(brew --version | head -1))"

# The installer's closing "Next steps" tells you to append a `brew shellenv`
# line to ~/.zprofile. Do not. modules/system/homebrew/default.nix already puts
# /opt/homebrew/bin on environment.systemPath, so nix-darwin manages it for
# every shell it owns. Adding it by hand duplicates the entry and leaves a
# machine-local edit that the repo cannot see -- exactly what settings/globals.nix
# exists to avoid.
warn "Ignore the installer's 'add Homebrew to your PATH' instruction above."
detail "modules/system/homebrew/default.nix declares /opt/homebrew/bin on"
detail "environment.systemPath. nix-darwin wires it into every managed shell"
detail "after the first rebuild -- no ~/.zprofile edit needed, and one added by"
detail "hand would just duplicate it."
detail "This script already loaded brew into the current run, so the bootstrap"
detail "can continue without restarting your terminal."
