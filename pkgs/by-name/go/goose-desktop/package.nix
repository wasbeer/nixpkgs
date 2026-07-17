{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  nodejs,
  python3,
  uv,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libsecret,
  libxkbcommon,
  libgcc,
  mesa,
  nspr,
  nss,
  pango,
  pulseaudio,
  systemd,
  vulkan-loader,
  xdg-utils,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxshmfence,
}:

let
  deps = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libsecret
    libxkbcommon
    libgcc.lib
    mesa
    nspr
    nss
    pango
    pulseaudio
    (lib.getLib systemd) # libudev.so.1 is a direct NEEDED of the Electron binary
    vulkan-loader
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxshmfence
  ];

  libPath = lib.makeLibraryPath deps;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "goose-desktop";
  version = "1.43.0";

  src = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${finalAttrs.version}/goose_${finalAttrs.version}_amd64.deb";
    hash = "sha256-6pEqVxdUF1KAT+5OIDFBqahYerzbZiq+0uRv0lMmYMk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = deps;

  # dlopen'd at runtime rather than listed as NEEDED; baked into rpath of every
  # ELF in $out (including the spawned resources/bin/goose backend) so child
  # processes resolve them without inheriting LD_LIBRARY_PATH.
  runtimeDependencies = [
    (lib.getLib systemd)
    libnotify
    libsecret
    pulseaudio
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    # Pipe through tar with --no-same-permissions so the setuid bit on
    # chrome-sandbox isn't restored (the Nix sandbox forbids it, and we run
    # with --no-sandbox anyway).
    dpkg-deb --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib,share,libexec/goose}

    # The app is a self-contained electron-forge package (its own Electron
    # runtime, resources/app.asar and the bundled `goose` backend).
    cp -r usr/lib/goose $out/lib/goose

    # MCP extensions are launched through the helper shims in resources/bin.
    # Upstream's shims bootstrap cashapp/hermit: they curl a generated hermit
    # bash script into ~/.config/goose and use it to download prebuilt
    # python/node/jdk toolchains on first run. Neither half works here -- the
    # downloaded hermit starts with `#!/bin/bash`, and the toolchains it fetches
    # are linked against /lib64/ld-linux-x86-64.so.2. Substitute the nixpkgs
    # toolchains so hermit is never reached. jbang is dropped rather than
    # wrapped: it would pull a full JDK into the closure, and an extension that
    # needs it now fails with a plain "not found".
    rm $out/lib/goose/resources/bin/{node,npx,uvx,jbang,node-setup-common.sh}

    # LD_LIBRARY_PATH set by the launcher below is for Goose's own bundled
    # Electron; these toolchains resolve their libraries through their rpath and
    # must not inherit it (same hazard as the xdg-open shim).
    makeWrapper ${lib.getExe' nodejs "node"} $out/lib/goose/resources/bin/node \
      --unset LD_LIBRARY_PATH

    makeWrapper ${lib.getExe' nodejs "npx"} $out/lib/goose/resources/bin/npx \
      --unset LD_LIBRARY_PATH \
      --prefix PATH : "${lib.makeBinPath [ nodejs ]}"

    # uv defaults to fetching a python-build-standalone interpreter, which
    # cannot run on NixOS; pin it to the nixpkgs python3 on PATH instead.
    makeWrapper ${lib.getExe' uv "uvx"} $out/lib/goose/resources/bin/uvx \
      --unset LD_LIBRARY_PATH \
      --prefix PATH : "${lib.makeBinPath [ python3 ]}" \
      --set-default UV_PYTHON_DOWNLOADS never \
      --set-default UV_PYTHON_PREFERENCE only-system

    # Application icon.
    install -Dm644 usr/share/pixmaps/goose.png \
      $out/share/icons/hicolor/512x512/apps/goose.png

    # Electron's bundled ANGLE dlopen()s libEGL.so.1 from libglvnd, which
    # autoPatchelfHook cannot discover, so the wrapper below has to export
    # LD_LIBRARY_PATH. That variable is inherited by every child, including the
    # browser that `xdg-open` spawns for external links -- Goose's older nss
    # then shadows the browser's own and it dies with an XPCOM/NSS version
    # error. Shim xdg-open so the handoff to the browser starts from a clean
    # loader environment; it is placed ahead of xdg-utils on the wrapper's PATH.
    makeWrapper ${lib.getExe' xdg-utils "xdg-open"} $out/libexec/goose/xdg-open \
      --unset LD_LIBRARY_PATH

    # Nix cannot setuid chrome-sandbox in the store, so always disable it.
    makeWrapper $out/lib/goose/Goose $out/bin/goose-desktop \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --prefix PATH : "$out/libexec/goose:${lib.makeBinPath [ xdg-utils ]}" \
      --prefix LD_LIBRARY_PATH : "${libPath}" \
      --inherit-argv0

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "goose-desktop";
      desktopName = "Goose";
      exec = "goose-desktop %U";
      icon = "goose";
      type = "Application";
      terminal = false;
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/goose" ];
      startupWMClass = "Goose";
    })
  ];

  meta = {
    description = "Desktop GUI for the Goose AI agent";
    homepage = "https://github.com/aaif-goose/goose";
    license = lib.licenses.asl20;
    mainProgram = "goose-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
