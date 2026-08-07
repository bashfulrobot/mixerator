{ ... }:

{
  # Editors / writing
  apps.gui.glide.enable = true;
  apps.gui.zed.enable = true;
  apps.gui.typora.enable = true;

  # Installed by hand before this repo existed; declared here so the repo is a
  # record of what I actually chose. Everything else in /Applications was
  # deployed by Kandji and is deliberately left unmanaged.
  apps.gui.rectangle-pro.enable = true;
  apps.gui.macwhisper.enable = true;
  apps.gui.tailscale.enable = true;

  # Claude Code, with ~/.claude under Nix management + capture.
  apps.cli.claude-code.enable = true;
}
