{
  description = "Nix-Darwin configuration with flakes and home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      globals = import ./settings/globals.nix;
      secretsFile = "${self}/secrets/secrets.json";
      secrets =
        if builtins.pathExists secretsFile then
          builtins.fromJSON (builtins.readFile secretsFile)
        else
          { };
      lib = import ./lib { inherit inputs secrets; };
    in
    {
      darwinConfigurations = {
        donkeykong = lib.mkHost {
          inherit globals;
          hostname = "donkeykong";
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
