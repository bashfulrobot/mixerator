# Architecture

## Directory structure

```
flake.nix              -- inputs, darwinConfigurations, formatter
lib/
  default.nix           -- re-exports mkHost + autoimport helpers
  mkHost.nix             -- darwinSystem builder shared by every host
  autoimport.nix          -- recursive .nix importer used by modules/default.nix
settings/
  globals.nix             -- single source of truth: user info, paths, defaults, preferences
hosts/
  HOSTNAME/
    configuration.nix       -- imports ./modules.nix + ../../modules, sets archetypes/system.stateVersion
    modules.nix              -- per-host option toggles (which apps/suites this machine gets)
    home.nix                  -- per-host home-manager entry point
modules/
  apps/
    cli/                       -- command-line tools (git, fish, starship, claude-code)
    gui/                        -- graphical applications (ghostty, zed, upsight, ...)
  suites/                       -- grouped bundles of modules (core, terminal)
  system/                       -- system-level config (macOS defaults, homebrew integration, fonts)
  archetypes/                    -- high-level host profiles that turn on suites + system modules
secrets/                          -- git-crypt-encrypted secrets.json; empty/absent is a valid state
extras/docs/                       -- this file
```

## Flake outputs

`flake.nix` pulls in `nixpkgs`, `nix-darwin`, `home-manager`, `apple-fonts`,
`determinate` (Determinate Nix integration), and the private `upsight` flake.
It loads `settings/globals.nix` and, if present, `secrets/secrets.json`
(decrypted by git-crypt), then builds `lib = import ./lib { inherit inputs
secrets; }`. Every host is declared under `darwinConfigurations` as a call to
`lib.mkHost`.

## `lib.mkHost`

`lib/mkHost.nix` wraps `nix-darwin.lib.darwinSystem`. It:

- Threads `inputs`, `hostname`, `globals`, `secrets` through both
  `specialArgs` (system modules) and `home-manager.extraSpecialArgs` (home
  modules), so every module can request `globals`/`secrets` as a function
  argument without extra plumbing.
- Imports `hosts/<hostname>/configuration.nix` plus the Determinate Nix and
  home-manager darwin modules.
- Sets `determinateNix.enable = true` and disables nix-darwin's own Nix
  management, because this machine runs Determinate Nix and the two
  daemons cannot both own `/etc/nix/nix.conf`.
- Wires `home-manager.users.${globals.user.name}` to `hosts/<hostname>/home.nix`.

`extraModules` / `homeManagerModules` let a host append modules outside the
auto-imported tree, though in practice every host so far uses only the
auto-imported set.

## Module auto-import

`modules/default.nix` is the *only* place modules get imported --
`autoImportLib.simpleAutoImport ./.` recursively finds every `.nix` file
under `modules/` and imports it, except:

- `default.nix` files themselves (each subdirectory has its own, which is
  what actually defines that module -- the recursion just needs to reach it),
- and any path containing `disabled`, `build`, `cfg`, or `reference`
  (`lib/autoimport.nix:21-26`), which lets a module carry drafts,
  private/build-only Nix, or reference material without it being evaluated.

Because of this, **no module should ever be imported by hand** from a host
file or another module -- it would either double-import or (for an excluded
subdir) evade the exclusion. `hosts/*/configuration.nix` only imports
`./modules.nix` (per-host toggles) and `../../modules` (the whole tree via
`modules/default.nix`) -- never an individual module file.

## Module shape and namespaces

Every module follows the same pattern:

```nix
{ config, lib, ... }:
let
  cfg = config.NAMESPACE.PATH;
in
{
  options.NAMESPACE.PATH.enable = lib.mkEnableOption "...";
  config = lib.mkIf cfg.enable { ... };
}
```

The option namespace normally mirrors the module's directory path:
`modules/apps/cli/git` -> `apps.cli.git`, `modules/suites/core` ->
`suites.core`, `modules/archetypes/workstation` -> `archetypes.workstation`.

Two modules deliberately break that mirroring to avoid colliding with
options nix-darwin/home-manager already define at the "expected" name:

- `modules/system/defaults` exposes `system.macos-defaults`, not
  `system.defaults` (nix-darwin's own macOS-preferences option tree).
- `modules/system/homebrew` exposes `system.homebrew-integration`, not
  `system.homebrew` (nix-darwin's real Homebrew module, which this module
  configures internally via the top-level `homebrew.*` options).

## Archetypes and suites

`archetypes.workstation` (the only archetype so far) is the top-level
profile a host enables: it turns on `suites.core`, `suites.terminal`,
`system.macos-defaults`, and `system.homebrew-integration`. Suites group
related modules -- `suites.core` is the non-optional baseline (git, shell
user, Touch ID for sudo, basic CLI tools); `suites.terminal` is the
terminal/shell experience (ghostty, fish, starship, fonts, modern CLI
replacements). A host can enable an archetype for the bundle, or reach past
it and enable individual `apps.*`/`suites.*` options directly, as
`hosts/MH36P2YMHX/modules.nix` does for its GUI apps and Claude Code.

## Secrets

`secrets/` is git-crypt-encrypted (`.gitattributes` routes `secrets/**`
through the `git-crypt` filter). `flake.nix` reads `secrets/secrets.json`
only if it exists, so an empty/absent secrets file is a valid, expected
state -- modules that need a secret must guard access with
`lib.optionalAttrs (secrets.foo or null != null) { ... }` rather than
assuming the key is present.
