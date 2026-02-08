{
  stdenv,
  lib,
  fetchurl,
  copyDesktopItems,
  makeDesktopItem,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  dotnet-runtime_8,
  expat,
  gdk-pixbuf,
  glib,
  gnutar,
  gtk3,
  icu,
  libdrm,
  libsecret,
  libxkbcommon,
  libgbm,
  mesa,
  nspr,
  nss,
  openssl,
  pango,
  systemd,
  wrapGAppsHook3,
  xdg-utils,
  libxrandr,
  libxfixes,
  libxext,
  libxdamage,
  libxcomposite,
  libx11,
  libxshmfence,
  libxcb,
  zlib,
}:

let
  desktopItem = makeDesktopItem {
    name = "azure-storage-explorer";
    desktopName = "Microsoft Azure Storage Explorer";
    comment = "Easily work with Azure Storage data on Windows, macOS, and Linux";
    genericName = "Storage Manager";
    exec = "azure-storage-explorer --no-sandbox %U";
    icon = "azure-storage-explorer";
    startupNotify = true;
    categories = [
      "Utility"
      "Development"
    ];
    keywords = [ "azure" "storage" "cloud" ];
  };
in
stdenv.mkDerivation rec {
  pname = "azure-storage-explorer";
  version = "1.41.0";

  desktopItems = [ desktopItem ];

  src = fetchurl {
    url = "https://github.com/microsoft/AzureStorageExplorer/releases/download/v${version}/StorageExplorer-linux-x64.tar.gz";
    sha256 = "sha256-//BJ9BoytQCE8+7PgEDN1J/hhkjw4LheFzHPvM2SlFc=";
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = [
    at-spi2-core
    at-spi2-atk
    libsecret
  ];

  targetPath = "$out/opt/azure-storage-explorer";

  unpackPhase = ''
    mkdir -p ${targetPath}
    ${gnutar}/bin/tar xf $src -C ${targetPath}
  '';

  installPhase = ''
    runHook preInstall

    # Install icon
    mkdir -p $out/share/pixmaps
    if [ -f ${targetPath}/resources/app/out/app/icon.png ]; then
      cp ${targetPath}/resources/app/out/app/icon.png $out/share/pixmaps/azure-storage-explorer.png
    fi

    runHook postInstall
  '';

  dotnetRuntime = dotnet-runtime_8.unwrapped;
  dotnetRoot = "${dotnetRuntime}/share/dotnet";

  rpath = lib.makeLibraryPath [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    dotnetRuntime
    expat
    gdk-pixbuf
    glib
    gtk3
    icu
    libdrm
    libgbm
    libsecret
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxshmfence
    mesa
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc
    systemd
    zlib
  ];

  preFixup = ''
    # Patch the main executable
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      ${targetPath}/StorageExplorerExe

    # Patch and wrap .NET ServiceHub binaries
    for binary in \
      ${targetPath}/resources/app/ServiceHub/Controllers/microsoft-servicehub-controller/Microsoft.ServiceHub.Controller \
      ${targetPath}/resources/app/ServiceHub/Hosts/microsoft-servicehub-host/ServiceHub.Host.dotnet.x64
    do
      if [ -f "$binary" ]; then
        patchelf \
          --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
          --set-rpath "${rpath}" \
          "$binary" || true

        # Create wrapper for .NET binary
        mv "$binary" "$binary.real"
        makeWrapper \
          "$binary.real" \
          "$binary" \
          --set DOTNET_ROOT ${dotnetRoot} \
          --set LD_LIBRARY_PATH ${rpath} \
          --prefix PATH : ${dotnetRoot}
      fi
    done

    mkdir -p $out/bin
    makeWrapper \
      ${targetPath}/StorageExplorer \
      $out/bin/azure-storage-explorer \
      --set LD_LIBRARY_PATH ${rpath} \
      --set DOTNET_ROOT ${dotnetRoot} \
      --prefix PATH : ${dotnetRoot} \
      --suffix PATH : ${lib.makeBinPath [ dbus xdg-utils ]} \
      --suffix PATH : /run/current-system/sw/bin
  '';

  meta = {
    description = "Storage management solution for working with Azure Storage on Windows, macOS, and Linux";
    homepage = "https://azure.microsoft.com/en-us/products/storage/storage-explorer/";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "azure-storage-explorer";
    maintainers = with lib.maintainers; [ ];
  };
}
