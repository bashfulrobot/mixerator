{ ... }:

{
  imports = [
    ./modules.nix
    ../../modules
  ];

  # Hostname is MDM-assigned and deliberately left unmanaged -- setting
  # networking.hostName / computerName here would fight the MDM profile.

  archetypes.workstation.enable = true;

  # nix-darwin state version
  system.stateVersion = 6;
}
