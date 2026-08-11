{
  globals,
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.zoxide;

  # Pinned inline rather than via a versions.nix the way nixerator does it --
  # this repo has no such indirection, only settings/globals.nix, and one
  # fish plugin does not justify introducing the mechanism. Bump both fields
  # together; a stale hash fails the build rather than silently fetching the
  # old tree.
  zoxideFish = {
    version = "3.0";
    hash = "sha256-OjrX0d8VjDMxiI5JlJPyu/scTs/fS/f5ehVyhAA/KDM=";
  };
in
{
  options = {
    apps.cli.zoxide.enable = lib.mkEnableOption "zoxide for smarter directory navigation";
  };

  config = lib.mkIf cfg.enable {

    home-manager.users.${globals.user.name} = {

      programs.zoxide = {
        enable = true;
        # Off deliberately: the zoxide.fish plugin below installs its own
        # integration, and running both gives you two `z` definitions racing
        # to bind the same name.
        enableFishIntegration = false;
      };

      # zoxide.fish completes real directories first and only then falls back
      # to zoxide's frecency database, and it aliases `cd` to `z` -- so plain
      # `cd` gains the memory rather than making you learn a second verb.
      # https://github.com/icezyclon/zoxide.fish
      programs.fish.plugins = [
        {
          name = "zoxide.fish";
          src = pkgs.fetchFromGitHub {
            owner = "icezyclon";
            repo = "zoxide.fish";
            rev = zoxideFish.version;
            inherit (zoxideFish) hash;
          };
        }
      ];

    };

  };
}
