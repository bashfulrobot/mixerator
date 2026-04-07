# Mixerator

Modular nix-darwin configuration with flakes and home-manager for macOS.

## Status

Scaffold. Porting modules from [nixerator](https://github.com/bashfulrobot/nixerator).

## Quick Start

```bash
# First-time setup (requires nix-darwin installed)
darwin-rebuild switch --flake .#HOSTNAME

# Using justfile
just rebuild      # Rebuild and switch
just upgrade      # Update flake inputs and rebuild
just clean        # Garbage collect
just fmt          # Format nix files
```

## Configuration

**Global settings**: `settings/globals.nix`

**Host-specific**: `hosts/HOSTNAME/configuration.nix`

Enable modules via options:
```nix
{
  archetypes.workstation.enable = true;
  apps.cli.git.enable = true;
}
```

## Module Categories

```
modules/
  apps/
    cli/       # Command-line tools
    gui/       # Graphical applications
  suites/      # Grouped module collections
  system/      # System-level config (defaults, homebrew)
  archetypes/  # High-level host profiles
```
