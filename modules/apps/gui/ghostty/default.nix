{
  config,
  lib,
  globals,
  ...
}:

let
  cfg = config.apps.gui.ghostty;
in
{
  options = {
    apps.gui.ghostty.enable = lib.mkEnableOption "the Ghostty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    # Ghostty is not in nixpkgs for darwin; install via Homebrew cask
    homebrew = {
      enable = true;
      casks = [ "ghostty" ];
    };

    home-manager.users.${globals.user.name} = {
      programs.ghostty = {
        enable = true;
        package = null; # Installed via Homebrew, not nix
        enableFishIntegration = true;
        installBatSyntax = true;
        settings = {
          window-decoration = false;
          window-padding-x = 20;
          window-padding-y = 20;
          scrollback-limit = 100000;
          copy-on-select = "clipboard";
          confirm-close-surface = false;
          cursor-style = "bar";
          mouse-hide-while-typing = true;
        };
      };
    };
  };
}
