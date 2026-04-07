{
  hostname,
  globals,
  ...
}:

{
  imports = [
    ./modules.nix
    ../../modules
  ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  archetypes.workstation.enable = true;

  # nix-darwin state version
  system.stateVersion = 6;
}
