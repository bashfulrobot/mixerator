{
  pkgs,
  lib,
  globals,
  ...
}:

{
  home = {
    username = globals.user.name;
    inherit (globals.user) homeDirectory;
    inherit (globals.defaults) stateVersion;

    packages = with pkgs; [
      htop
      tree
      ripgrep
      fd
      bat
    ];

    sessionVariables = {
      EDITOR = lib.mkForce (lib.getExe pkgs.${globals.preferences.editor});
    };
  };

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };
}
