{
  config,
  lib,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.claude-code;

  configDir = ./config;
  homeDir = globals.user.homeDirectory;
  claudeHome = "${homeDir}/.claude";

  # Bidirectional capture between ~/.claude and this repo, ported verbatim from
  # nixerator. Claude Code rewrites its own config as you work, so the repo can
  # never be the sole writer -- the script reconciles both sides against a SHA
  # snapshot in config/.capture-state.json and refuses to guess when they have
  # diverged independently (see `just capture-resolve`).
  captureScript = pkgs.writeShellScriptBin "claude-capture" ''
    set -euo pipefail
    repo="''${MIXERATOR_ROOT:-${globals.paths.mixerator}}"
    config_dir="$repo/modules/apps/cli/claude-code/config"
    if [ ! -d "$config_dir" ]; then
      echo "claude-capture: $config_dir not found." >&2
      echo "  Set MIXERATOR_ROOT if the repo lives somewhere other than ${globals.paths.mixerator}." >&2
      exit 1
    fi

    # capture-sync.py's settings.json reconcile is capture-only and expects a
    # CANONICALIZED home copy (see run_settings()'s docstring in
    # cfg/scripts/capture-sync.py): activation writes home as
    # jq-merge(home, sed(repo)) below, so a declared key's home value is
    # always either verbatim repo content or repo content with
    # @USER_NAME@/@HOME_DIR@ substituted -- never anything structurally new.
    # Passing the raw live file here instead (as this used to) would compare
    # against repo's still-templated placeholders and show "diverged" on
    # every run, so capture would silently overwrite the repo template with
    # rendered, placeholder-free content. Canonicalizing reverses that:
    # project home onto repo's key shape (drops runtime-only keys like
    # theme/enabledPlugins/skillOverrides) then substitute the literal
    # values back to placeholders -- longest-match first, since
    # ${homeDir} contains ${globals.user.name} as a substring.
    if [ -f "${claudeHome}/settings.json" ]; then
      canonical_settings="$(mktemp)"
      trap 'rm -f "$canonical_settings"' EXIT
      ${pkgs.jq}/bin/jq \
        --slurpfile repo "$config_dir/settings.json" \
        'def project(repo):
           if (repo | type) == "object" and (. | type) == "object" then
             with_entries(.key as $k | select(repo | has($k)) | .value |= project(repo[$k]))
           else
             .
           end;
         project($repo[0])' \
        "${claudeHome}/settings.json" \
        | ${pkgs.gnused}/bin/sed \
            -e 's|${homeDir}|@HOME_DIR@|g' \
            -e 's|${globals.user.name}|@USER_NAME@|g' \
        > "$canonical_settings"
    else
      # Doesn't exist -- pass the path through as-is so sha256_file's
      # exists() check (correctly) reports no home settings to capture.
      canonical_settings="${claudeHome}/settings.json"
    fi

    ${pkgs.python3}/bin/python3 \
      "$repo/modules/apps/cli/claude-code/cfg/scripts/capture-sync.py" \
      --state-file "$config_dir/.capture-state.json" \
      --home-root "${claudeHome}" \
      --repo-root "$config_dir" \
      --settings-home "$canonical_settings" \
      --settings-repo "$config_dir/settings.json" \
      --section all \
      "$@"
  '';
in
{
  options = {
    apps.cli.claude-code.enable = lib.mkEnableOption "Claude Code with Nix-managed configuration";
  };

  config = lib.mkIf cfg.enable {
    # Claude Code ships as a Homebrew cask on darwin (the nixpkgs derivation
    # nixerator uses is Linux-only). Declaring it here is also what keeps the
    # cask from being treated as undeclared drift.
    #
    # `@latest` tracks the latest release channel, so new versions land as soon
    # as they ship. The plain `claude-code` cask tracks stable, which trails by
    # about a week and skips releases with major regressions. Neither cask
    # auto-updates -- `brew upgrade claude-code@latest` is the explicit act,
    # matching `onActivation.upgrade = false` in the homebrew module.
    homebrew = {
      enable = true;
      casks = [ "claude-code@latest" ];
    };

    # Written as a function so `lib` here is home-manager's extended lib, which
    # is what carries `lib.hm.dag`. The `lib` in a nix-darwin module is plain
    # nixpkgs lib and has no `hm` attribute.
    home-manager.users.${globals.user.name} =
      { lib, ... }:
      {
        home.packages = [ captureScript ];

        # Files are COPIED, not symlinked into the store. Claude Code writes to
        # settings.json (theme, enabledPlugins, skillOverrides) and may rewrite
        # agents at runtime; a read-only store symlink would either break those
        # writes or silently drift. Copies stay writable and `claude-capture`
        # pulls deliberate changes back into git.
        home.activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          claude_home="${claudeHome}"
          run mkdir -p "$claude_home/agents" "$claude_home/output-styles"

          # GNU cp from nixpkgs: macOS ships BSD cp, which has no --no-preserve.
          # Without it the copies inherit the store's read-only mode.
          gcp="${pkgs.coreutils}/bin/cp --no-preserve=mode -f"

          run $gcp "${configDir}/CLAUDE.md" "$claude_home/CLAUDE.md"
          run $gcp "${configDir}/agents/"*.md "$claude_home/agents/"
          run $gcp "${configDir}/output-styles/"*.md "$claude_home/output-styles/"

          # settings.json: Nix owns every key it declares, the runtime keeps the
          # rest. `jq -s '.[0] * .[1]'` deep-merges with the Nix side on the
          # right, so declared objects win and declared arrays (the permission
          # lists) replace wholesale rather than accumulating stale entries --
          # while runtime-only keys like `theme` survive untouched.
          if [ -z "''${DRY_RUN_CMD:-}" ]; then
            rendered="$(mktemp)"
            ${pkgs.gnused}/bin/sed \
              -e 's|@USER_NAME@|${globals.user.name}|g' \
              -e 's|@HOME_DIR@|${homeDir}|g' \
              "${configDir}/settings.json" > "$rendered"

            if [ -f "$claude_home/settings.json" ]; then
              ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
                "$claude_home/settings.json" "$rendered" > "$claude_home/settings.json.tmp"
              mv "$claude_home/settings.json.tmp" "$claude_home/settings.json"
            else
              cp "$rendered" "$claude_home/settings.json"
            fi
            rm -f "$rendered"
          fi
        '';
      };
  };
}
