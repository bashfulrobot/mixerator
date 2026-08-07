{
  config,
  lib,
  ...
}:

let
  cfg = config.apps.gui.macwhisper;
in
{
  options = {
    apps.gui.macwhisper.enable = lib.mkEnableOption "MacWhisper local speech-to-text";
  };

  config = lib.mkIf cfg.enable {
    # Not in nixpkgs for darwin; install via Homebrew cask.
    # macOS counterpart to voxtype on the NixOS hosts.
    homebrew = {
      enable = true;
      casks = [ "macwhisper" ];
    };
  };
}
