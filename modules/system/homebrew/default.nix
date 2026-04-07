{
  lib,
  config,
  ...
}:

let
  cfg = config.system.homebrew-integration;
in
{
  options = {
    system.homebrew-integration.enable = lib.mkEnableOption "Homebrew integration for GUI apps not in nixpkgs";
  };

  config = lib.mkIf cfg.enable {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "zap";
        upgrade = true;
      };
      casks = [
        # Add casks here as needed
      ];
      taps = [ ];
      brews = [ ];
    };
  };
}
