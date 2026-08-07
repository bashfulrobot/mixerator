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
        # "none", deliberately. This repo is a record of what I chose to
        # install, not an enforcer. Kandji deploys apps outside brew and I
        # install things by hand between rebuilds; "zap" removes every
        # undeclared cask *and its data* on the next switch, which would have
        # taken out the claude-code cask on the very first rebuild.
        cleanup = "none";

        # Rebuilds stay fast and deterministic. Upgrading brew is an explicit
        # act (`brew upgrade`), not a side effect of activating a generation.
        autoUpdate = false;
        upgrade = false;
      };
      casks = [
        # Add casks here as needed
      ];
      taps = [ ];
      brews = [ ];
    };
  };
}
