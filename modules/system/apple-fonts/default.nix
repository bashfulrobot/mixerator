{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.system.apple-fonts;
  appleFontsPkgs = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options = {
    system.apple-fonts = {
      enable = lib.mkEnableOption "Nerd Font patched Apple fonts (SF Mono Nerd)";

      packages = {
        sf-mono-nerd = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = appleFontsPkgs.sf-mono-nerd;
          description = "SF Mono Nerd font package.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = [
      cfg.packages.sf-mono-nerd
    ];
  };
}
