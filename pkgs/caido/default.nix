{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  _7zz,
  unzip,
  libgcc,
  webkitgtk_4_1,
  gtk3,
  openssl,
  libsoup_3,
  appVariants ? [ ],
}:
let
  pname = "caido";
  appVariantList = [
    "cli"
    "desktop"
  ];
  version = "0.55.3";

  system = stdenv.hostPlatform.system;
  isLinux = stdenv.isLinux;
  isDarwin = stdenv.isDarwin;

  # CLI sources
  cliSources = {
    x86_64-linux = {
      url = "https://caido.download/releases/v${version}/caido-cli-v${version}-linux-x86_64.tar.gz";
      hash = "sha256-1sqj19lci050yzwgv4aw6zn2fj2b8j7l4c3py9fjw6r3xlq61kna="; # Replace with actual hash
    };
    aarch64-linux = {
      url = "https://caido.download/releases/v${version}/caido-cli-v${version}-linux-aarch64.tar.gz";
      hash = "sha256-09605r34wrlhnfrbwj0zwk97l4cyg993i4npy2ykpjyd36ss9x96="; # Replace with actual hash
    };
    x86_64-darwin = {
      url = "https://caido.download/releases/v${version}/caido-cli-v${version}-mac-x86_64.zip";
      hash = "sha256-1y2w758ldik5jpmkbkqclcgpbxhsdfzj8wagir13f3ccq5mlcwbf="; # Replace with actual hash
    };
    aarch64-darwin = {
      url = "https://caido.download/releases/v${version}/caido-cli-v${version}-mac-aarch64.zip";
      hash = "sha256-1q1msn34xyf3wqrjwgy9qavkk3qwxcjr0ifqf8w9yq5c84m50l2i="; # Replace with actual hash
    };
  };

  # Desktop sources (Updated to use .deb for Linux)
  desktopSources = {
    x86_64-linux = {
      url = "https://caido.download/releases/v${version}/caido-desktop-v${version}-linux-x86_64.deb";
      hash = "sha256-07g9hjpvhwnxq0gjk66s840rrmwabzhlpsdlm65fsx1kki0svavl="; # Replace with actual hash
    };
    aarch64-linux = {
      url = "https://caido.download/releases/v${version}/caido-desktop-v${version}-linux-aarch64.deb";
      hash = "sha256-100l40dai1l00yscn0cpwai6ghg93dx7k0pg6579ka2n012nrpkw="; # Replace with actual hash
    };
    x86_64-darwin = {
      url = "https://caido.download/releases/v${version}/caido-desktop-v${version}-mac-x86_64.dmg";
      hash = "sha256-1k1vkakd1561fd2sm74ybdk57kskvg6mgw0z0lrim1zhli2xnzap="; # Replace with actual hash
    };
    aarch64-darwin = {
      url = "https://caido.download/releases/v${version}/caido-desktop-v${version}-mac-aarch64.dmg";
      hash = "sha256-13kqpdsna4wkl0hhhif3ci9d5bmmixcn20854bjjp89krqvwyk3w="; # Replace with actual hash
    };
  };

  cliSource = cliSources.${system} or (throw "Unsupported system for caido-cli: ${system}");
  desktopSource =
    desktopSources.${system} or (throw "Unsupported system for caido-desktop: ${system}");

  cli = fetchurl {
    url = cliSource.url;
    hash = cliSource.hash;
  };

  desktop = fetchurl {
    url = desktopSource.url;
    hash = desktopSource.hash;
  };

  wrappedDesktop =
    if isLinux then
      stdenv.mkDerivation {
        inherit pname version;
        src = desktop;

        nativeBuildInputs = [
          dpkg
          autoPatchelfHook
          makeWrapper
          wrapGAppsHook3
        ];

        buildInputs = [
          libgcc
          webkitgtk_4_1
          gtk3
          libsoup_3
          openssl
        ];

        unpackPhase = ''
          dpkg-deb -x $src .
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out
          cp -r usr/* $out/

          # Fix desktop file path
          substituteInPlace $out/share/applications/caido.desktop \
            --replace "/opt/Caido/caido" "$out/bin/caido"

          runHook postInstall
        '';

        # Runtime fixes for Tauri/Electron/WebKit
        postFixup = ''
          wrapProgram $out/bin/caido \
            --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
        '';

        meta = {
          platforms = [
            "x86_64-linux"
            "aarch64-linux"
          ];
        };
      }
    else if isDarwin then
      stdenv.mkDerivation {
        src = desktop;
        inherit pname version;

        nativeBuildInputs = [ _7zz ];
        sourceRoot = ".";

        unpackPhase = ''
          runHook preUnpack
          ${_7zz}/bin/7zz x $src
          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/Applications
          cp -r Caido.app $out/Applications/
          mkdir -p $out/bin
          ln -s $out/Applications/Caido.app/Contents/MacOS/Caido $out/bin/caido
          runHook postInstall
        '';

        meta = {
          platforms = [
            "x86_64-darwin"
            "aarch64-darwin"
          ];
        };
      }
    else
      throw "Desktop variant is not supported on ${stdenv.hostPlatform.system}";

  wrappedCli =
    if isLinux then
      stdenv.mkDerivation {
        src = cli;
        inherit pname version;

        nativeBuildInputs = [ autoPatchelfHook ];
        buildInputs = [ libgcc ];
        sourceRoot = ".";

        installPhase = ''
          runHook preInstall
          install -m755 -D caido-cli $out/bin/caido-cli
          runHook postInstall
        '';
      }
    else if isDarwin then
      stdenv.mkDerivation {
        src = cli;
        inherit pname version;

        nativeBuildInputs = [ unzip ];
        sourceRoot = ".";

        installPhase = ''
          runHook preInstall
          install -m755 -D caido-cli $out/bin/caido-cli
          runHook postInstall
        '';

        meta = {
          platforms = [
            "x86_64-darwin"
            "aarch64-darwin"
          ];
        };
      }
    else
      throw "CLI variant is not supported on ${stdenv.hostPlatform.system}";

  meta = {
    description = "Lightweight web security auditing toolkit";
    homepage = "https://caido.io/";
    changelog = "https://github.com/caido/caido/releases/tag/v${version}";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      octodi
      blackzeshi
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
in
lib.checkListOfEnum "${pname}: appVariants" appVariantList appVariants (
  if appVariants == [ "desktop" ] then
    wrappedDesktop
  else if appVariants == [ "cli" ] then
    wrappedCli
  else
    stdenv.mkDerivation {
      inherit pname version meta;
      dontUnpack = true;
      installPhase = ''
        mkdir -p $out/bin
        ln -s ${wrappedDesktop}/bin/caido $out/bin/caido
        ln -s ${wrappedCli}/bin/caido-cli $out/bin/caido-cli
      '';
    }
)
