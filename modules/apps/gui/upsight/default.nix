{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  ...
}:

let
  cfg = config.apps.gui.upsight;

  # Built here rather than taken from inputs.upsight.packages: that flake gates
  # its packages behind isLinux, so there is no darwin output to consume. See
  # build/default.nix for what differs from the upstream Linux derivation.
  #
  # Built against upsight's OWN pinned nixpkgs (nixos-26.05), not mixerator's
  # unstable. Two reasons, one of them load-bearing:
  #
  #   1. Upstream pins it deliberately for reproducibility, and nixerator
  #      likewise declines to make this input follow its nixpkgs.
  #   2. The build needs pnpm 9 for a lockfileVersion 9.0 lockfile, and current
  #      unstable marks pnpm 9.15.9 with ten CVEs, so evaluation refuses it. The
  #      26.05 pin predates those advisories. This is a build-time fetch tool
  #      running in a sandboxed FOD -- nothing from pnpm reaches the shipped
  #      binary -- but it IS an unpatched pnpm, and the honest fix is upstream
  #      moving to a pnpm the current nixpkgs still blesses. Scoping it here
  #      beats a system-wide permittedInsecurePackages entry.
  #
  # The cost is a second nixpkgs in the eval closure.
  upsightPkgs = import inputs.upsight.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
  };

  # Versions mirror upsight's own flake.nix. Keep them in step when bumping the
  # input -- they are the app version stamped into the binary and the pinned
  # wails3 CLI, neither of which is discoverable from the source tree.
  upsight-pkg = upsightPkgs.callPackage ./build {
    src = inputs.upsight;
    version = "0.0.1";
    wails3Version = "v3.0.0-beta.2";
  };
in
{
  options = {
    apps.gui.upsight.enable = lib.mkEnableOption "Upsight CSM desktop application";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ upsight-pkg ];
    };
  };
}
