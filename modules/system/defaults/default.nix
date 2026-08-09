{
  lib,
  config,
  ...
}:

let
  cfg = config.system.macos-defaults;
in
{
  # Named macos-defaults rather than the directory-mirroring `system.defaults`
  # deliberately -- nix-darwin already owns that namespace for the real
  # dock/finder/NSGlobalDomain option tree this module writes into below.
  options = {
    system.macos-defaults.enable = lib.mkEnableOption "macOS system preference defaults";
  };

  config = lib.mkIf cfg.enable {
    system.defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
        minimize-to-application = true;
        show-recents = false;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };
}
