{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.glide;
in
{
  options = {
    apps.gui.glide.enable = lib.mkEnableOption "Glide tiling window manager for macOS";
  };

  config = lib.mkIf cfg.enable {
    # Install via Homebrew (not in nixpkgs). Glide ships as a cask, not a
    # formula -- declaring it under `brews` made brew bundle look for a
    # formula named glide, which does not exist, and fail the whole bundle.
    homebrew = {
      enable = true;
      casks = [ "glide" ];
    };

    # User configuration
    home-manager.users.${globals.user.name} = {
      xdg.configFile."glide/glide.toml".text = ''
        [settings]
        animate = true
        default_disable = true
        focus_follows_mouse = true
        mouse_follows_focus = true
        mouse_hides_on_focus = true
        outer_gap = 0
        inner_gap = 0
        default_layout_kind = "tree"
        default_keys = false

        group_bars.enable = true
        group_bars.thickness = 6
        group_bars.horizontal_placement = "top"
        group_bars.vertical_placement = "right"

        status_icon.enable = true

        [keys]
        "Alt + Shift + E" = "save_and_exit"
        "Alt + Z" = "toggle_space_activated"

        # Focus
        "Alt + H" = { move_focus = "left" }
        "Alt + J" = { move_focus = "down" }
        "Alt + K" = { move_focus = "up" }
        "Alt + L" = { move_focus = "right" }

        # Move windows
        "Alt + Shift + H" = { move_node = "left" }
        "Alt + Shift + J" = { move_node = "down" }
        "Alt + Shift + K" = { move_node = "up" }
        "Alt + Shift + L" = { move_node = "right" }

        # Resize
        "Alt + Ctrl + H" = { resize = { direction = "left", percent = 5 } }
        "Alt + Ctrl + J" = { resize = { direction = "down", percent = 5 } }
        "Alt + Ctrl + K" = { resize = { direction = "up", percent = 5 } }
        "Alt + Ctrl + L" = { resize = { direction = "right", percent = 5 } }

        # Tree navigation
        "Alt + A" = "ascend"
        "Alt + D" = "descend"

        # Layouts
        "Alt + N" = "next_layout"
        "Alt + P" = "prev_layout"

        # Splits and groups
        "Alt + Backslash" = { split = "horizontal" }
        "Alt + Equal" = { split = "vertical" }
        "Alt + T" = { group = "horizontal" }
        "Alt + S" = { group = "vertical" }
        "Alt + E" = "ungroup"

        # Floating and fullscreen
        "Alt + Shift + Space" = "toggle_window_floating"
        "Alt + Space" = "toggle_focus_floating"
        "Alt + F" = "toggle_fullscreen"

        # Debug
        "Alt + Shift + D" = "debug"

        [settings.experimental]
        status_icon.space_index = false
        status_icon.color = false
        status_icon.enable = true
        scroll.enable = false
      '';
    };
  };
}
