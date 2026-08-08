{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.suites.core;
in
{
  options = {
    suites.core.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable core macOS configuration suite.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Git, signing and the surrounding tooling. Baseline rather than opt-in:
    # this repo is the only way to change the machine, and every change to it
    # is a commit.
    apps.cli.git.enable = true;

    # Essential CLI tools available system-wide
    environment.systemPackages = with pkgs; [
      wget
      curl
      ripgrep
      fd
      bat
      tree
    ];

    # User shell
    users.users.${globals.user.name} = {
      shell = pkgs.${globals.preferences.shell};
      home = globals.user.homeDirectory;
    };

    # Touch ID for sudo
    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
