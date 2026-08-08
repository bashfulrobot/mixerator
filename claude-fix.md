# Fixing Claude Code on macOS (keychain / PATH issues)

## Symptoms

- `claude` can't log in.
- `claude doctor` reports the keychain is not writable.
- `claude doctor` reports the native binary is not on PATH.

## Root cause

Claude Code should be installed on macOS via the **Homebrew cask**
(`claude-code@latest`), which this repo already declares in
`modules/apps/cli/claude-code/default.nix`. If a different install method
was ever used alongside it (npm global install, the curl/native installer
script, or a Nix-built binary), you end up with two problems:

1. **Keychain not writable** -- macOS Keychain access grants are bound to a
   specific binary's path/code signature. A Nix-built binary lives under
   `/nix/store/<hash>-...`, and that hash changes on every rebuild/update, so
   each new store path looks like a different app to Keychain and can't
   reuse the previously granted "Claude Code-credentials" item. A
   Homebrew-installed binary at a stable path doesn't have this problem.
2. **Native binary not on PATH** -- multiple installs (e.g. a leftover
   `~/.local/bin/claude` from the curl installer, or an npm global install)
   compete on PATH, and whichever resolves first may not be the one
   `claude doctor` expects.

Additionally, nix-darwin does not put Homebrew's bin dir (`/opt/homebrew/bin`)
on `PATH` by default. This repo now sets that explicitly in
`modules/system/homebrew/default.nix` via `environment.systemPath`, so
PATH resolution no longer depends on shell-specific init order.

## Steps to fix, on the Mac

1. **Pull the latest changes** (or merge the `claude/mac-install-issues-gyoyf2`
   branch) so `environment.systemPath` includes `/opt/homebrew/bin`.

2. **Find what's currently providing `claude`:**

   ```
   which -a claude
   type -a claude
   ```

3. **Remove any non-Homebrew installs:**

   ```
   npm uninstall -g @anthropic-ai/claude-code   # if present
   ```

   If you ever ran the curl/native installer, remove its artifacts:

   ```
   rm -rf ~/.local/bin/claude ~/.local/share/claude
   ```

   (Check `claude doctor`'s output for the exact paths it flags first.)

4. **Clear the stale Keychain item** so it isn't bound to the old binary:

   - Keychain Access.app -> search "Claude Code" -> delete the item, or
   - `security delete-generic-password -s "Claude Code-credentials"`

5. **Rebuild with this repo's config:**

   ```
   just qr
   ```

   This applies `apps.cli.claude-code.enable` (installs/updates the
   `claude-code@latest` Homebrew cask) and the new `environment.systemPath`
   entry for `/opt/homebrew/bin`.

6. **Verify:**

   ```
   which claude          # should resolve under /opt/homebrew/bin
   claude doctor
   claude login
   ```

If `claude doctor` still complains after this, re-check step 2/3 for a
lingering install shadowing the Homebrew one on PATH.
