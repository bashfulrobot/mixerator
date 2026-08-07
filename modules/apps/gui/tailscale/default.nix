{
  config,
  lib,
  ...
}:

let
  cfg = config.apps.gui.tailscale;
in
{
  options = {
    apps.gui.tailscale.enable = lib.mkEnableOption "the Tailscale macOS client";
  };

  config = lib.mkIf cfg.enable {
    # The cask is "tailscale-app": the plain "tailscale" cask was renamed when
    # the name was reassigned to the CLI-only formula. This is the standalone
    # (non-App-Store) macOS build, which is what was installed here by hand.
    #
    # Deliberately not the nixerator apps/cli/tailscale module: that one runs
    # tailscaled as a NixOS service, whereas the Mac client is a GUI app that
    # owns its own daemon and network extension.
    homebrew = {
      enable = true;
      casks = [ "tailscale-app" ];
    };
  };
}
