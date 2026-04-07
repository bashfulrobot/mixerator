{ inputs, secrets }:

{
  mkHost =
    {
      globals,
      hostname,
      system,
      stateVersion ? globals.defaults.stateVersion,
      extraModules ? [ ],
      homeManagerModules ? [ ],
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = {
        inherit
          inputs
          hostname
          globals
          secrets
          ;
      };

      modules = [
        ../hosts/${hostname}/configuration.nix

        inputs.home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          # Automatic garbage collection via launchd
          nix.gc = {
            automatic = true;
            interval = {
              Weekday = 0;
              Hour = 2;
              Minute = 0;
            };
            options = "--delete-older-than 14d";
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit
                inputs
                hostname
                globals
                secrets
                ;
            };
            users.${globals.user.name} = {
              imports = [ ../hosts/${hostname}/home.nix ] ++ homeManagerModules;
            };
            backupCommand = "${
              inputs.nixpkgs.legacyPackages.${system}.bash
            }/bin/bash -c 'if [ -e \"$1\" ]; then mv -f \"$1\" \"$1.backup-$(date +%Y%m%d-%H%M%S)\"; ls -t \"$1\".backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f; fi' --";
          };
        }
      ] ++ extraModules;
    };
}
