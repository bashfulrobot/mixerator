{
  lib,
  config,
  ...
}:

let
  cfg = config.archetypes.workstation;
in
{
  options = {
    archetypes.workstation.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable workstation archetype with core suite, macOS defaults, and Homebrew integration.";
    };
  };

  config = lib.mkIf cfg.enable {
    suites.core.enable = true;
    system.macos-defaults.enable = true;
    system.homebrew-integration.enable = true;
  };
}
