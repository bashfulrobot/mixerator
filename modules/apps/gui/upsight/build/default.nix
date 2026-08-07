# upsight for macOS.
#
# Adapted from the upstream Linux derivation (nix/upsight.nix in the upsight
# repo), which throws on darwin. Upstream's reason is that the WebKitGTK webview
# has no darwin counterpart in Nixpkgs -- true, but on macOS Wails links the
# system WKWebView out of the Apple SDK that the darwin stdenv already carries,
# so the GTK stack simply isn't needed rather than being unavailable.
#
# What is reused unchanged from upstream, because none of it is platform-bound:
#   * the pinned wails3 CLI, built from source (CGO_ENABLED=0)
#   * the Go module set (proxyVendor, so vendorHash is source-derived)
#
# What differs from the Linux build:
#   * no webkitgtk/gtk4/glib/libsoup/gsettings buildInputs
#   * no wrapGAppsHook4, no LD_LIBRARY_PATH or XDG_DATA_DIRS wrapper
#   * no .desktop entry (copyDesktopItems is a freedesktop concept)
#   * no bundled hunspell dictionary -- macOS spell-checks through NSSpellChecker
#   * pnpmDeps needs its own hash: pnpm lockfiles carry platform-specific
#     optional deps (esbuild/rollup ship per-platform binaries), so the darwin
#     fetch is not bit-identical to upstream's linux one.
{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  pnpm_9,
  nodejs_22,
  pkg-config,
  makeWrapper,
  poppler-utils,
  # Source tree of the upsight flake input.
  src,
  version,
  wails3Version,
}:

let
  # Byte-identical to upstream's. The CLI links no native libraries and only
  # orchestrates builds, so it is portable as-is.
  wails3 = buildGoModule {
    pname = "wails3";
    version = lib.removePrefix "v" wails3Version;

    src = fetchFromGitHub {
      owner = "wailsapp";
      repo = "wails";
      rev = wails3Version;
      hash = "sha256-X0+oLM+3MOBw43SpYh7vpuwxqHCgT9opEdPsF+v9lrw=";
    };

    modRoot = "v3";
    subPackages = [ "cmd/wails3" ];

    # `go mod vendor` resolves every package's go:embed patterns, including
    # Windows-only webview2loader DLLs absent from the source tarball, which
    # fails. proxyVendor populates the module cache instead.
    proxyVendor = true;
    vendorHash = "sha256-88RqtT9LyvMdIyhXA3wuIIdurwHcP3DaMl1HD338IV8=";

    env = {
      CGO_ENABLED = "0";
      GOWORK = "off";
    };

    doCheck = false;

    meta = {
      description = "Wails v3 CLI (pinned alpha) used to generate bindings and orchestrate builds";
      homepage = "https://v3.wails.io/";
      license = lib.licenses.mit;
      mainProgram = "wails3";
    };
  };

  # Byte-identical to upstream's Linux hash, verified by building here. pnpm's
  # fetchDeps stores the packed tarballs rather than a platform-resolved
  # node_modules, so the per-platform optional binaries (esbuild, rollup) don't
  # move it. Cross-platform reproducible, in other words -- no darwin-specific
  # value needed.
  pnpmDeps = pnpm_9.fetchDeps {
    pname = "upsight-frontend";
    inherit version;
    src = "${src}/frontend";
    fetcherVersion = 3;
    hash = "sha256-j6Nm2+NJPHx7+kBcsXLQbaCSF2e02zY/NCieBTSV35I=";
  };
in
buildGoModule {
  pname = "upsight";
  inherit version src;

  proxyVendor = true;
  vendorHash = "sha256-fcEVYd3epvUO0YOKPJ8bt7dcEjle4h1fH72CVvM/f7c=";

  # Wails links the native webview (WKWebView on darwin) through cgo.
  env.CGO_ENABLED = "1";

  nativeBuildInputs = [
    wails3
    pnpm_9
    pnpm_9.configHook
    nodejs_22
    pkg-config
    makeWrapper
  ];

  # buildGoModule's child "go-modules" FOD inherits nativeBuildInputs, and
  # pnpmConfigHook would abort there ("'pnpmDeps' must be set"). Strip the pnpm
  # machinery from it; it only needs the Go toolchain. Same fix as upstream.
  overrideModAttrs = old: {
    nativeBuildInputs = builtins.filter (x: x != pnpm_9.configHook) (old.nativeBuildInputs or [ ]);
    pnpmDeps = null;
    pnpmRoot = null;
    preBuild = "";
  };

  inherit pnpmDeps;
  pnpmRoot = "frontend";

  tags = [ "production" ];
  ldflags = [
    "-w"
    "-s"
    "-X github.com/bashfulrobot/upsight-go/internal/core/cli.Version=${version}"
    "-X github.com/bashfulrobot/upsight-go/internal/core/diagnostics.Version=${version}"
    # Point the packaged app at the real Syncthing'd DB rather than the
    # gitignored dev copy, matching upstream's packaged build.
    "-X github.com/bashfulrobot/upsight-go/internal/core/db.PackagedRealDB=1"
  ];
  subPackages = [ "." ];

  # Two steps `task build` performs that buildGoModule does not: generate the
  # Wails TS bindings the Svelte frontend imports, then vite-build the frontend
  # that main.go embeds via go:embed.
  preBuild = ''
    echo "Generating Wails TS bindings..."
    HOME=$TMPDIR wails3 generate bindings \
      -f '-tags production -trimpath -buildvcs=false' \
      -clean=true -ts -i

    echo "Building Svelte frontend (vite)..."
    pushd frontend
    npm run build
    popd
  '';

  # buildGoModule names the binary after the module's last path element
  # (upsight-go); the CLI and app both expect `upsight`.
  postInstall = ''
    mv "$out/bin/upsight-go" "$out/bin/upsight"
  '';

  # pdftotext is a runtime dependency of win-wire PDF import and document text
  # extraction -- the app shells out to it by bare name. Upstream leaves this
  # host-provided on macOS (`brew install poppler`); pinning it here instead
  # means the feature works without that manual step, the same way the Linux
  # package handles it.
  postFixup = ''
    mv "$out/bin/upsight" "$out/bin/.upsight-unwrapped"
    makeWrapper "$out/bin/.upsight-unwrapped" "$out/bin/upsight" \
      --prefix PATH : "${lib.makeBinPath [ poppler-utils ]}"
  '';

  doCheck = false;

  meta = {
    description = "Local-first desktop app for technical CSMs at Kong (Go + Wails v3 + Svelte 5)";
    homepage = "https://github.com/bashfulrobot/upsight";
    license = lib.licenses.mit;
    mainProgram = "upsight";
    platforms = lib.platforms.darwin;
    broken = !stdenv.hostPlatform.isDarwin;
  };
}
