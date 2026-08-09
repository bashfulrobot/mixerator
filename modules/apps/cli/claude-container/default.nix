{
  config,
  lib,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.claude-container;

  homeDir = globals.user.homeDirectory;
  gitRoot = globals.paths.gitRoot;
  devRoot = globals.paths.devRoot;

  # Separate from ~/.claude deliberately -- sharing that directory with the
  # macOS-native Claude Code install risks the two colliding over
  # .credentials.json (see anthropics/claude-code#10039, where the macOS
  # build has deleted the Linux build's credentials file when they share a
  # path). This lives under $HOME so it's still a real, persistent directory
  # on the Mac's disk, just not the one macOS Claude Code touches.
  containerConfigDir = "${homeDir}/.claude-container";

  containerName = "claude-host";
  containerImage = "ubuntu:24.04";

  # On Linux, Claude Code stores its OAuth credentials in a plain
  # ~/.claude/.credentials.json file rather than a keychain (see
  # code.claude.com/docs/en/authentication#credential-management) -- running
  # it inside this Linux container sidesteps the macOS Keychain bug in
  # anthropics/claude-code#70077 entirely, structurally, rather than working
  # around it. This is the only reason the container exists: not sandboxing,
  # not reproducibility, just a working non-macOS credential store.
  claudeContainerScript = pkgs.writeShellScriptBin "claude-container" ''
    set -euo pipefail

    docker="${pkgs.docker}/bin/docker"
    colima="${pkgs.colima}/bin/colima"

    if ! "$colima" status >/dev/null 2>&1; then
      echo "claude-container: starting Colima..." >&2
      "$colima" start
    fi

    if ! "$docker" inspect ${containerName} >/dev/null 2>&1; then
      echo "claude-container: creating persistent container..." >&2
      mkdir -p "${containerConfigDir}"
      "$docker" run --name ${containerName} -d \
        -v "${gitRoot}:${gitRoot}" \
        -v "${devRoot}:${devRoot}" \
        -v "${containerConfigDir}:${containerConfigDir}" \
        -w "${homeDir}" \
        ${containerImage} sleep infinity
    elif [ "$("$docker" inspect -f '{{.State.Running}}' ${containerName})" != "true" ]; then
      "$docker" start ${containerName} >/dev/null
    fi

    # Bootstrap only -- guarded on the launcher already existing so this
    # never re-runs on a normal invocation and never fights the native
    # installer's own background auto-updater, same rule as the host-side
    # bootstrap in apps.cli.claude-code.
    if ! "$docker" exec ${containerName} test -x /root/.local/bin/claude 2>/dev/null; then
      echo "claude-container: bootstrapping Claude Code inside the container..." >&2
      "$docker" exec ${containerName} bash -c \
        "apt-get update -qq && apt-get install -y -qq curl ca-certificates && curl -fsSL https://claude.ai/install.sh | bash"
    fi

    # Preserve the working directory across the host/container boundary --
    # paths match 1:1 since ~/git and ~/dev are mounted at identical
    # locations -- but fall back to $HOME if run from outside either, since
    # nothing else on the Mac's filesystem exists inside the container.
    workdir="$PWD"
    case "$workdir" in
      "${gitRoot}"*|"${devRoot}"*) ;;
      *) workdir="${homeDir}" ;;
    esac

    exec "$docker" exec -it \
      -e "CLAUDE_CONFIG_DIR=${containerConfigDir}" \
      -e "PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      -w "$workdir" \
      ${containerName} claude "$@"
  '';
in
{
  options = {
    apps.cli.claude-container.enable = lib.mkEnableOption "Colima-based Linux container running Claude Code, to work around the macOS Keychain login bug (anthropics/claude-code#70077)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.colima
      pkgs.docker
      claudeContainerScript
    ];
  };
}
