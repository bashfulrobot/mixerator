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

        inputs.determinate.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;

          # Required by current nix-darwin: every user-scoped `system.defaults`
          # option (dock, finder, NSGlobalDomain) errors out without it.
          system.primaryUser = globals.user.name;

          # This machine runs Determinate Nix, whose determinate-nixd owns the
          # daemon and /etc/nix/nix.conf. nix-darwin aborts activation
          # alongside it unless its own Nix management stands down, which this
          # module does -- it sets nix.enable = false itself, so the whole
          # `nix.*` tree is off-limits from here.
          #
          # Settings go to determinateNix.customSettings instead, which lands
          # them in /etc/nix/nix.custom.conf. Nothing was lost in the move:
          # flakes and nix-command are Determinate defaults, and Determinate
          # runs its own garbage collection rather than nix-darwin's launchd
          # timer, so both settings this used to declare are now redundant.
          determinateNix.enable = true;

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
      ]
      ++ extraModules;
    };
}
