{
  config,
  lib,
  ...
}:

let
  cfg = config.apps.gui.rectangle-pro;
in
{
  options = {
    apps.gui.rectangle-pro.enable = lib.mkEnableOption "the Rectangle Pro window manager";
  };

  config = lib.mkIf cfg.enable {
    # Not in nixpkgs for darwin; install via Homebrew cask.
    # Was drag-installed by hand before this module existed -- brew will adopt
    # the existing bundle in /Applications on the next rebuild.
    homebrew = {
      enable = true;
      casks = [ "rectangle-pro" ];
    };
  };
}
