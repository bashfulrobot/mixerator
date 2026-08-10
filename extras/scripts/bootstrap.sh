#!/usr/bin/env bash
#
# Guided bootstrap for a fresh Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/bashfulrobot/mixerator/main/extras/scripts/bootstrap.sh | bash
#
# or, from an existing checkout:
#
#   ./extras/scripts/bootstrap.sh
#
# Order matters:
#   1. preflight     -- 1Password, SSH auth, Xcode CLT
#   2. Determinate   -- everything downstream needs nix
#   3. Homebrew      -- nix-darwin's homebrew.casks drives an existing brew
#   4. clone         -- the flake has to be on disk to build from
#   5. nix-darwin    -- first switch, from inside the repo
#   6. Claude Code   -- optional; not managed by Nix
#
# Set MIXERATOR_YES=1 to accept every prompt (unattended).

# Tildes below are prose meant for the reader, not paths to expand.
# shellcheck disable=SC2088

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

export STEP_TOTAL=6
export STEP_INDEX=0

# Children are separate processes, so they cannot increment our counter. Export
# the running total before each one, then advance it ourselves afterwards.
run_child() {
  export STEP_INDEX
  "$@"
  STEP_INDEX=$((STEP_INDEX + 1))
}

banner() {
  printf '%s\n' "$C_BOLD$C_BLUE"
  printf '  mixerator bootstrap\n'
  printf '%s' "$C_RESET"
  printf '  %sA fresh-Mac setup for %s%s\n' "$C_DIM" "$REPO_SSH_URL" "$C_RESET"
}

# ------------------------------------------------------------------------------
# 1. Preflight
# ------------------------------------------------------------------------------
preflight() {
  step "Preflight"

  require_macos
  ok "macOS $(sw_vers -productVersion)"

  arch="$(uname -m)"
  if [ "$arch" != "arm64" ]; then
    warn "Architecture is $arch; flake.nix only defines aarch64-darwin hosts."
  else
    ok "Architecture arm64"
  fi

  host="$(target_hostname)"
  ok "Hostname $host"

  # Xcode Command Line Tools. `git` on a bare macOS is a shim that pops a GUI
  # installer when invoked, which would stall an unattended run.
  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode Command Line Tools present"
  else
    warn "Xcode Command Line Tools are missing."
    detail "Homebrew's installer pulls them in, but git is needed before that."
    if confirm "Trigger the Command Line Tools install now?"; then
      xcode-select --install || true
      detail "Finish the GUI installer, then re-run this script."
      exit 0
    fi
    die "Command Line Tools are required."
  fi

  # 1Password. This is a hard prerequisite, and not only for the clone: see the
  # SSH check below.
  if [ -d "$ONEPASSWORD_APP" ]; then
    ok "1Password installed"
  else
    err "1Password is not installed at $ONEPASSWORD_APP"
    detail "Install it and sign in before bootstrapping -- your SSH keys live there."
    exit 1
  fi

  if [ -S "$ONEPASSWORD_AGENT_SOCK" ]; then
    ok "1Password SSH agent socket present"
  else
    err "1Password's SSH agent is not running."
    detail "Open 1Password → Settings → Developer → 'Use the SSH agent',"
    detail "make sure you are signed in and unlocked, then re-run."
    exit 1
  fi

  # ~/.ssh/config is NOT managed by this repo -- nothing in modules/ writes it.
  # 1Password's 'Configure SSH agent' button is what creates it. Without the
  # IdentityAgent line, ssh ignores the agent entirely.
  if [ -f "$HOME/.ssh/config" ] && grep -q "IdentityAgent" "$HOME/.ssh/config" 2>/dev/null; then
    ok "~/.ssh/config points at an IdentityAgent"
  else
    warn "~/.ssh/config has no IdentityAgent line."
    detail "This repo does not manage that file -- 1Password writes it via"
    detail "Settings → Developer → 'Configure SSH agent'. The check below will"
    detail "tell us whether ssh can actually reach GitHub regardless."
  fi

  # The decisive check. flake.nix pulls a PRIVATE input over ssh://git@github.com
  # (the upsight repo), so the flake cannot even evaluate without working SSH
  # auth. This must pass BEFORE the first darwin-rebuild, not after it.
  info "Testing SSH auth to GitHub…"
  ssh_out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 -T git@github.com 2>&1 || true)"
  if printf '%s' "$ssh_out" | grep -q "successfully authenticated"; then
    ok "GitHub SSH auth works ($(printf '%s' "$ssh_out" | head -1))"
  else
    err "Cannot authenticate to GitHub over SSH."
    detail "$(printf '%s' "$ssh_out" | head -3)"
    detail ""
    detail "This is a hard blocker, not just for cloning: flake.nix has a private"
    detail "input (ssh://git@github.com/bashfulrobot/upsight), so nix cannot"
    detail "evaluate the flake at all without it. Fix SSH first:"
    detail "  - 1Password unlocked, SSH agent enabled"
    detail "  - the GitHub key present in 1Password and added to your account"
    exit 1
  fi

  pause
}

# ------------------------------------------------------------------------------
# 4. Clone
# ------------------------------------------------------------------------------
clone_repo() {
  step "Clone mixerator"

  if [ -d "$REPO_DIR/.git" ]; then
    skip "Already cloned at $REPO_DIR"
    return 0
  fi

  if [ -e "$REPO_DIR" ]; then
    die "$REPO_DIR exists but is not a git checkout. Move it aside and re-run."
  fi

  info "Cloning $REPO_SSH_URL"
  info "     to $REPO_DIR"
  if ! confirm "Clone now?"; then
    die "Declined. The repo has to be on disk to build from."
  fi

  mkdir -p "$GIT_ROOT"
  git clone "$REPO_SSH_URL" "$REPO_DIR"
  ok "Cloned to $REPO_DIR"
}

# ------------------------------------------------------------------------------
main() {
  banner
  preflight
  STEP_INDEX=1

  run_child "$SCRIPT_DIR/install-determinate.sh"
  run_child "$SCRIPT_DIR/install-homebrew.sh"

  clone_repo
  STEP_INDEX=$((STEP_INDEX + 1))

  # Prefer the freshly cloned copy's scripts over whatever ran us -- if this was
  # piped from curl, SCRIPT_DIR is a temp dir with no siblings.
  if [ -d "$REPO_DIR/extras/scripts" ]; then
    SCRIPT_DIR="$REPO_DIR/extras/scripts"
  fi

  run_child "$SCRIPT_DIR/install-nix-darwin.sh"
  run_child "$SCRIPT_DIR/install-claude.sh"

  printf '\n%s✓ Bootstrap complete%s\n\n' "$C_BOLD$C_GREEN" "$C_RESET"

  # Shell environment, explicitly, because the installers give advice that is
  # wrong for this repo. Each step re-derived its own PATH in-process (see
  # load_nix_env / load_brew_env in lib/common.sh), which is why the run got
  # this far without a restart -- but THIS shell is still the old one.
  warn "Do not add anything to ~/.zshrc or ~/.zprofile."
  detail "Both Homebrew's and Claude's installers suggest it. This repo declares"
  detail "those PATH entries instead:"
  detail "  /opt/homebrew/bin   modules/system/homebrew/default.nix"
  detail "  ~/.local/bin        modules/apps/cli/claude-code/default.nix"
  detail "Hand-editing a dotfile duplicates them and hides machine-local state"
  detail "from the repo."
  printf '\n'

  info "Next:"
  detail "  1. Open a NEW terminal. This one predates Nix, Homebrew and the"
  detail "     nix-darwin switch, so its PATH and shell are stale."
  detail "  2. cd $REPO_DIR"
  detail "  3. just rebuild   # from now on, instead of these scripts"
  printf '\n'
}

main "$@"
