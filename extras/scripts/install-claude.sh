#!/usr/bin/env bash
#
# Install Claude Code via Anthropic's native installer.
#
# Deliberately outside Nix. modules/apps/cli/claude-code manages ~/.claude
# config only -- the binary is installed by hand here and self-updates in the
# background from ~/.local/share/claude/versions/. Keeping Nix out of it means
# activation can never fight the auto-updater over which version is current.
#
# Not the Homebrew cask: a Homebrew- or Nix-managed binary's path changes on
# every update, which collided with macOS Keychain ACLs. See claude-fix.md.
#
# Idempotent: exits early unless --force is passed.

# Tildes below are prose meant for the reader, not paths to expand.
# shellcheck disable=SC2088

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_macos

force=0
if [ "${1:-}" = "--force" ]; then
  force=1
fi

step "Claude Code"

launcher="$HOME/.local/bin/claude"

if [ -e "$launcher" ] && [ "$force" -eq 0 ]; then
  skip "Claude Code already installed at $launcher"
  detail "It self-updates. Pass --force to reinstall anyway."
  exit 0
fi

info "Installs to ~/.local/share/claude/versions/ with a launcher at"
info "~/.local/bin/claude. No sudo required."
if ! confirm "Install Claude Code now?"; then
  detail "Skipped. Run this script later, or install by hand:"
  detail "  curl -fsSL https://claude.ai/install.sh | bash"
  exit 0
fi

curl -fsSL https://claude.ai/install.sh | bash

if [ ! -e "$launcher" ]; then
  die "Installer finished but $launcher does not exist."
fi

ok "Claude Code installed"

# The installer may suggest adding ~/.local/bin to your shell profile. Skip it:
# modules/apps/cli/claude-code declares it on environment.systemPath instead.
# That module is currently disabled for this host, though, so until it is turned
# back on nothing puts ~/.local/bin on PATH declaratively.
if ! have claude; then
  warn "~/.local/bin is not on this shell's PATH."
  detail "Ignore any 'add this to ~/.zshrc' advice from the installer --"
  detail "modules/apps/cli/claude-code declares it on environment.systemPath."
  detail "That module is disabled for this host right now (see"
  detail "hosts/*/modules.nix), so either re-enable it and rebuild, or for this"
  detail "terminal only: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
