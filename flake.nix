{
  description = "Nix-Darwin configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts = {
      url = "github:lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This machine runs Determinate Nix. Its determinate-nixd owns the daemon
    # and /etc/nix/nix.conf, and nix-darwin refuses to activate alongside it
    # unless told to stand down. This module is the supported way to do that:
    # it disables nix-darwin's own Nix management and gives back a declarative
    # settings surface via `determinateNix.customSettings`, written to
    # /etc/nix/nix.custom.conf. The bare alternative, `nix.enable = false`,
    # stands nix-darwin down but leaves no way to declare Nix settings at all.
    determinate.url = "github:DeterminateSystems/determinate";

    # upsight, the Wails v3 + Svelte CSM desktop app. Private repo, so this
    # needs SSH read access -- same git+ssh arrangement nixerator uses.
    #
    # Consumed for its SOURCE ONLY. Its flake gates `packages` behind
    # `lib.optionalAttrs isLinux`, so `packages.aarch64-darwin` is empty and
    # `inputs.upsight.packages.${system}.default` (what nixerator's module
    # uses) does not exist here. The darwin derivation lives in
    # modules/apps/gui/upsight/build/ instead.
    #
    # No `inputs.nixpkgs.follows`: upsight pins nixos-26.05 deliberately for
    # reproducibility, and we don't build from its package set anyway.
    upsight = {
      url = "git+ssh://git@github.com/bashfulrobot/upsight?ref=main";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      globals = import ./settings/globals.nix;
      secretsFile = "${self}/secrets/secrets.json";
      secrets =
        if builtins.pathExists secretsFile then builtins.fromJSON (builtins.readFile secretsFile) else { };
      lib = import ./lib { inherit inputs secrets; };
    in
    {
      darwinConfigurations = {
        MH36P2YMHX = lib.mkHost {
          inherit globals;
          hostname = "MH36P2YMHX";
          system = "aarch64-darwin";
          extraModules = [ ];
          homeManagerModules = [ ];
        };
      };

      formatter.aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-darwin = inputs.nixpkgs.legacyPackages.x86_64-darwin.nixfmt-tree;

      inherit lib globals;
    };
}
