{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.suites.terminal;
in
{
  options = {
    suites.terminal.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable terminal suite with shell, prompt, and terminal utilities.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Terminal emulator
    apps.gui.alacritty.enable = true;

    # Shell and prompt
    apps.cli = {
      fish.enable = true;
      starship.enable = true;
      zoxide.enable = true;
    };

    # Fonts
    system.apple-fonts.enable = true;

    # Terminal utilities - Modern Rust replacements for classic Unix tools
    environment.systemPackages = with pkgs; [
      # Build/task runner. Every workflow in this repo's justfile depends on
      # it, and nothing else declared it -- the scaffold assumed the host
      # already had it.
      just

      # Interactive utilities
      gum # Glamorous shell scripts (prompts, inputs, spinners)
      glow # Markdown renderer

      # Fuzzy finder. Not optional decoration: the af/ff/copy fish functions
      # (and the dormant kcfg/tcfg/kns) pipe through it, and every one of them
      # was silently broken here because nothing declared it.
      fzf

      # Modern Rust CLI tools
      bat # cat replacement with syntax highlighting
      dust # du replacement with tree visualization
      eza # ls replacement with colors and git integration
      fd # find replacement with better UX
      ripgrep # grep replacement (faster)
      tokei # Code statistics (lines of code counter)
      procs # ps replacement with colored output
      sd # sed replacement with simpler syntax
      bottom # top/htop replacement (system monitor)
      hyperfine # Command-line benchmarking tool
    ];
  };
}
