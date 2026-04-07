{
  config,
  lib,
  ...
}:

let
  cfg = config.apps.gui.typora;
in
{
  options = {
    apps.gui.typora.enable = lib.mkEnableOption "the Typora markdown editor";
  };

  config = lib.mkIf cfg.enable {
    # Typora is not in nixpkgs for darwin; install via Homebrew cask
    homebrew = {
      enable = true;
      casks = [ "typora" ];
    };
  };
}
