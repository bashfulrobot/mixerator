# shellcheck shell=bash
#
# Shared helpers for the mixerator bootstrap scripts. Sourced, never executed.
#
# Targets macOS's system bash (3.2) on purpose: these scripts run BEFORE Nix
# exists, so nothing newer is guaranteed to be on PATH. No associative arrays,
# no ${var,,}, no mapfile, no `local -n`.

if [ -n "${_MIXERATOR_COMMON_SH:-}" ]; then
  return 0
fi
_MIXERATOR_COMMON_SH=1

# --- Repo constants -----------------------------------------------------------
# Duplicated from settings/globals.nix rather than read from it: these scripts
# have to work on a machine with no Nix, so evaluating globals.nix is not an
# option. Keep the two in sync by hand if the paths ever move.
REPO_SSH_URL="${REPO_SSH_URL:-git@github.com:bashfulrobot/mixerator.git}"
REPO_HTTPS_URL="${REPO_HTTPS_URL:-https://github.com/bashfulrobot/mixerator.git}"
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
REPO_DIR="${REPO_DIR:-$GIT_ROOT/mixerator}"

# Consumed by bootstrap.sh's preflight, which shellcheck cannot see from here.
# shellcheck disable=SC2034
ONEPASSWORD_APP="/Applications/1Password.app"
# shellcheck disable=SC2034
ONEPASSWORD_AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# --- Output -------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_BLUE=''
fi

# Step counter. A parent script exports STEP_TOTAL so children can render
# "[3/6]"; standalone runs just get "==>".
STEP_INDEX="${STEP_INDEX:-0}"

step() {
  STEP_INDEX=$((STEP_INDEX + 1))
  printf '\n'
  if [ "${STEP_TOTAL:-0}" -gt 0 ]; then
    printf '%s==> [%d/%d] %s%s\n' "$C_BOLD$C_BLUE" "$STEP_INDEX" "$STEP_TOTAL" "$*" "$C_RESET"
  else
    printf '%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"
  fi
}

info() { printf '    %s\n' "$*"; }
detail() { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
ok() { printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip() { printf '    %s•%s %s %s(skipped)%s\n' "$C_GREEN" "$C_RESET" "$*" "$C_DIM" "$C_RESET"; }
warn() { printf '    %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err() { printf '    %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

die() {
  err "$*"
  exit 1
}

# --- Prompts ------------------------------------------------------------------
# Read from /dev/tty, not stdin, so prompts still work when a script is piped
# (curl ... | bash) or when stdin is otherwise consumed.

# `[ -r /dev/tty ]` is NOT a usable test: the node passes a permission check
# even in contexts where opening it fails with "Device not configured" (CI,
# detached processes, some agent harnesses). Actually opening it is the only
# reliable probe.
has_tty() {
  { exec 3</dev/tty; } 2>/dev/null || return 1
  exec 3<&-
  return 0
}

confirm() {
  _prompt="$1"
  if [ "${MIXERATOR_YES:-0}" = "1" ]; then
    detail "auto-confirmed: $_prompt"
    return 0
  fi
  if ! has_tty; then
    die "No terminal available to confirm '$_prompt'. Re-run with MIXERATOR_YES=1 to accept every prompt."
  fi
  _reply=''
  printf '    %s%s%s [y/N] ' "$C_BOLD" "$_prompt" "$C_RESET" >/dev/tty
  read -r _reply </dev/tty || _reply=''
  case "$_reply" in
    y | Y | yes | YES | Yes) return 0 ;;
    *) return 1 ;;
  esac
}

pause() {
  if [ "${MIXERATOR_YES:-0}" = "1" ] || ! has_tty; then
    return 0
  fi
  printf '    %sPress Enter to continue…%s' "$C_DIM" "$C_RESET" >/dev/tty
  read -r _ </dev/tty || true
  printf '\n'
}

# --- Probes -------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "These scripts are macOS-only (uname says $(uname -s))."
}

# Determinate installs here; a freshly-installed Nix is not yet on the PATH of
# the shell that ran the installer, so every script that needs `nix` sources
# this first.
load_nix_env() {
  if have nix; then
    return 0
  fi
  _nix_profile='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  if [ -e "$_nix_profile" ]; then
    # shellcheck disable=SC1090
    . "$_nix_profile"
  fi
  have nix
}

load_brew_env() {
  if have brew; then
    return 0
  fi
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$_brew" ]; then
      eval "$("$_brew" shellenv)"
      break
    fi
  done
  have brew
}

target_hostname() {
  scutil --get LocalHostName 2>/dev/null || hostname -s
}
