rec {
  # Global configuration variables available throughout your flake

  # User configuration
  user = {
    name = "dustin.krysak";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/Users/dustin.krysak";
  };

  # Common repository and development paths
  paths = {
    devRoot = "${user.homeDirectory}/dev";
    gitRoot = "${user.homeDirectory}/git";
    mixerator = "${user.homeDirectory}/git/mixerator";
  };

  # System defaults
  defaults = {
    stateVersion = "25.11";
    timeZone = "America/Vancouver";
    locale = "en_US.UTF-8";
  };

  # Editor and shell preferences
  preferences = {
    editor = "helix";
    shell = "fish";
    browser = "google-chrome";
    terminal = "ghostty";
  };

  # Git configuration
  git = {
    # SSH public key for commit signing
    gitPubSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICF9sPiX7zVCn+SW7bQpgS+dhUlVJYNktP6PO4mJWUJZ dustin@bashfulrobot.com";
  };

  # 1Password
  onePassword = {
    # 1Password's dedicated SSH signing helper, used as git's gpg.ssh.program.
    sshSignBin = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  };
}
