{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
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

    mkdir -p $out/{bin,lib,share}

    # The app is a self-contained electron-forge package (its own Electron
    # runtime, resources/app.asar and the bundled `goose` backend).
    cp -r usr/lib/goose $out/lib/goose

    # Helper shims (node/npx/uvx/jbang) ship with a /bin/bash shebang.
    patchShebangs $out/lib/goose/resources/bin

    # Application icon.
    install -Dm644 usr/share/pixmaps/goose.png \
      $out/share/icons/hicolor/512x512/apps/goose.png

    # Nix cannot setuid chrome-sandbox in the store, so always disable it.
    makeWrapper $out/lib/goose/Goose $out/bin/goose-desktop \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
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
