{ ... }:

{
  # Editors / writing -- staged rollout, re-enabling one at a time.
  apps.gui.glide.enable = false;
  apps.gui.zed.enable = false;
  apps.gui.typora.enable = false;

  # Installed by hand before this repo existed; declared here so the repo is a
  # record of what I actually chose. Everything else in /Applications was
  # deployed by Kandji and is deliberately left unmanaged.
  apps.gui.rectangle-pro.enable = false;
  apps.gui.macwhisper.enable = true;
  apps.gui.tailscale.enable = true;

  # Claude Code configuration. Re-enabled: the module no longer installs the
  # binary (that is done by hand with the native installer, see
  # extras/scripts/install-claude.sh), so enabling it deploys ~/.claude config
  # only -- permissions, agents, output styles, global CLAUDE.md.
  #
  # The macOS 26 Keychain regression (anthropics/claude-code#70077) is what
  # disabled this originally, but that was about the native install's login,
  # not about config; native Claude Code logs in fine on this machine now.
  # Without this enabled, ~/.claude/settings.json carried only theme + tui and
  # every deny rule in config/settings.json was dormant.
  apps.cli.claude-code.enable = true;

  # Colima-based Linux container running Claude Code, to work around the
  # macOS Keychain login bug (anthropics/claude-code#70077) -- see
  # modules/apps/cli/claude-container. Part of the staged rollout too.
  apps.cli.claude-container.enable = true;

  # Built from source for darwin here; upstream's flake is Linux-only.
  apps.gui.upsight.enable = false;
}
