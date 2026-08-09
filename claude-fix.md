# Fixing Claude Code on macOS (keychain / PATH issues)

## Symptoms

- `claude` can't log in.
- `claude doctor` reports the keychain is not writable.
- `claude doctor` reports the native binary is not on PATH.

## Root cause

This repo initially switched Claude Code to the Homebrew cask
(`claude-code@latest`) to get it off a Nix-built binary, whose
`/nix/store/<hash>-...` path changes on every rebuild and breaks macOS
Keychain ACLs (a new store path looks like a different app to Keychain each
time). That didn't fully resolve the issue on this machine, so the module now
uses Anthropic's **native installer** instead -- which Anthropic's own docs
label "Recommended" specifically because it manages a stable launcher path
and self-updates without any package manager rewriting the binary.

Whichever of these three install methods (native installer, Homebrew cask,
npm global) is currently in place, having **more than one at once** is what
actually causes both symptoms:

1. **Keychain not writable** -- Keychain access grants are bound to a
   specific binary's path/code signature. If the binary providing `claude`
   keeps changing path out from under a previously-granted Keychain item
   (Nix store churn, or two installs silently swapping which one PATH picks
   up), Keychain can't match the request to the grant.
2. **Native binary not on PATH** -- multiple installs compete on PATH, and
   whichever resolves first may not be the one `claude doctor` expects.

## Steps to fix, on the Mac

1. **Pull the latest changes** (or merge the `claude/mac-install-issues-gyoyf2`
   branch) so the claude-code module installs via the native installer and
   `environment.systemPath` includes `~/.local/bin`.

2. **Find what's currently providing `claude`:**

   ```
   which -a claude
   type -a claude
   ```

3. **Remove every other install method** so only the native installer remains:

   ```
   npm uninstall -g @anthropic-ai/claude-code   # if present
   brew uninstall --cask claude-code@latest      # if present
   brew uninstall --cask claude-code             # if present
   ```

4. **Clear the stale Keychain item** so it isn't bound to a stale binary:

   - Keychain Access.app -> search "Claude Code" -> delete the item, or
   - `security delete-generic-password -s "Claude Code-credentials"`

5. **Rebuild with this repo's config:**

   ```
   just qr
   ```

   This bootstraps the native installer (only if `~/.local/bin/claude`
   doesn't already exist -- see `modules/apps/cli/claude-code/README.md`) and
   sets `environment.systemPath` to include `~/.local/bin`.

6. **Verify:**

   ```
   which claude          # should resolve under ~/.local/bin
   claude doctor
   claude login
   ```

If `claude doctor` still complains after this, re-check step 2/3 for a
lingering install shadowing the native one on PATH -- both symptoms in this
doc trace back to more than one install method being present at once, not to
which method you pick.
