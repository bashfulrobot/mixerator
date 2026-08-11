{
  config,
  lib,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.apps.gui.alacritty;

  # Apple's own monospace, Nerd Font-patched -- native-looking on macOS and it
  # carries the powerline/devicon glyphs starship and eza expect. Installed by
  # system.apple-fonts (suites.terminal turns it on); "SFMono Nerd Font" is the
  # family name baked into the .otf, not the file name.
  fontFamily = "SFMono Nerd Font";
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
    assertions = [
      {
        assertion = config.system.apple-fonts.enable;
        message = "apps.gui.alacritty needs system.apple-fonts.enable for ${fontFamily}.";
      }
    ];

    home-manager.users.${globals.user.name} = {
      programs.alacritty = {
        enable = true;
        package = pkgs.alacritty;

        # TOML, mapped straight through to ~/.config/alacritty/alacritty.toml.
        # Option names verified against alacritty(5) for 0.17.
        settings = {
          window = {
            padding = {
              x = 20;
              y = 20;
            };

            # macOS draws the titlebar in the SYSTEM appearance, not the
            # terminal's -- which is why it renders white against a dark
            # colourscheme. This is the knob that fixes it; "Dark" is
            # independent of the macOS-wide light/dark setting.
            decorations_theme_variant = "Dark";

            # Left Option is the macOS compose key by default, which eats
            # Alt-b/Alt-f word motions in fish and readline.
            option_as_alt = "Both";
          };

          font = {
            normal = {
              family = fontFamily;
              style = "Regular";
            };
            # bold/italic inherit `family` from normal when unset.
            size = 15.0;
          };

          scrolling.history = 100000;
          cursor.style.shape = "Beam";
          selection.save_to_clipboard = true;
          mouse.hide_when_typing = true;
        };
      };
    };
  };
}
