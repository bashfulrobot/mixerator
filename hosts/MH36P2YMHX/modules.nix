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

  # Native macOS Claude Code -- disabled, not deleted. Login is broken by
  # the macOS 26 Keychain regression (anthropics/claude-code#70077) with no
  # fix available from this repo; superseded by apps.cli.claude-container
  # below, which runs Claude Code on Linux where credentials are a plain
  # file instead of Keychain. Config/capture tooling stays in the repo in
  # modules/apps/cli/claude-code in case the upstream bug gets fixed and
  # native install is worth re-enabling.
  apps.cli.claude-code.enable = false;

  # Colima-based Linux container running Claude Code, to work around the
  # macOS Keychain login bug (anthropics/claude-code#70077) -- see
  # modules/apps/cli/claude-container. Part of the staged rollout too.
  apps.cli.claude-container.enable = false;

  # Built from source for darwin here; upstream's flake is Linux-only.
  apps.gui.upsight.enable = false;
}
