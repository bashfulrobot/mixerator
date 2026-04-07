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
