{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.apps.gui.upsight;

  # upsight's own flake now builds on darwin (see nix/upsight.nix there: macOS
  # links the system WKWebView rather than WebKitGTK, so the Linux-only
  # webview stack was never actually required on this platform, just unused).
  # Consume the flake output directly -- same pattern nixerator's Linux module
  # uses -- rather than maintaining a parallel derivation here.
  upsight-pkg = inputs.upsight.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options = {
    apps.gui.upsight.enable = lib.mkEnableOption "Upsight CSM desktop application";
  };

  config = lib.mkIf cfg.enable {
    # System-level, not home-manager.home.packages: nix-darwin's builtin
    # `system.activationScripts.applications` only scans environment.
    # systemPackages for Applications/*.app to link into
    # /Applications/Nix Apps. home.packages is invisible to it, which is why
    # the previous home-manager-only install never showed up in Launchpad/
    # Spotlight -- only `upsight` on PATH.
    environment.systemPackages = [
      upsight-pkg
    ];
  };
}
