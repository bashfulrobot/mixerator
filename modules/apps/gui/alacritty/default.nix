{
  config,
  lib,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.apps.gui.alacritty;
in
{
  options = {
    apps.gui.alacritty.enable = lib.mkEnableOption "the Alacritty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    # nixpkgs, not a Homebrew cask -- the departure from the other modules in
    # apps/gui is deliberate. Those apps have no darwin build in nixpkgs, so a
    # cask is the only option. Alacritty does, it is unbroken for
    # aarch64-darwin, and it is prebuilt in cache.nixos.org, so routing it
    # through brew would only cost the version pin.
    #
    # The derivation ships both bin/alacritty and Applications/Alacritty.app;
    # home-manager's copyApps activation links the bundle into
    # ~/Applications/Home Manager Apps/, where Spotlight indexes it.
    home-manager.users.${globals.user.name} = {
      programs.alacritty = {
        enable = true;
        package = pkgs.alacritty;

        # TOML, mapped straight through to ~/.config/alacritty/alacritty.toml.
        settings = {
          window = {
            padding = {
              x = 4;
              y = 4;
            };
            option_as_alt = "Both";
          };
          scrolling.history = 100000;
          cursor.style.shape = "Beam";
          bell.duration = 0;
        };
      };
    };
  };
}
