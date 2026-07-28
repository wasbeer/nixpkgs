{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  at-spi2-atk,
  at-spi2-core,
  alsa-lib,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libpulseaudio,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nss,
  nspr,
  openssl,
  pango,
  systemd,
  vulkan-loader,
  xorg,
  ydotool,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openwhispr";
  version = "1.6.7";

  src = fetchurl {
    url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${finalAttrs.version}/OpenWhispr-${finalAttrs.version}-linux-amd64.deb";
    # Compute with:
    #   nix store prefetch-file --hash-type sha256 \
    #     https://github.com/OpenWhispr/openwhispr/releases/download/v1.6.7/OpenWhispr-1.6.7-linux-amd64.deb
    # Or: set hash = ""; and copy the correct hash from the nix-build error.
    hash = "sha256-2/zWuKUvB83gYRb5+9icZjReEmFA+ec9q3J4UBCe8Tc=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libstdc++.so.6, libgcc_s.so.1
    at-spi2-atk
    at-spi2-core
    alsa-lib
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm # libgbm.so.1 (GPU/software rendering)
    libpulseaudio # microphone capture via PulseAudio/PipeWire-pulse
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nss
    nspr
    openssl # libssl.so.3, libcrypto.so.3 (llama-server)
    pango
    vulkan-loader
    xorg.libXtst # libXtst.so.6 (linux-fast-paste)
  ];

  # Ignore optional deps that can't be satisfied on a non-CUDA glibc system:
  #   - musl libc variants of sentry profiler (glibc host, never loaded)
  #   - CUDA/TensorRT libs in onnxruntime (GPU-only, loaded only when GPU present)
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libcublas.so.12"
    "libcublasLt.so.12"
    "libcudart.so.12"
    "libcudnn.so.9"
    "libcufft.so.11"
    "libcurand.so.10"
    "libnvinfer.so.10"
    "libnvonnxparser.so.10"
  ];

  # libudev.so.1 is dlopen'd by Electron at runtime (not a DT_NEEDED entry)
  runtimeDependencies = [ (lib.getLib systemd) ];

  installPhase = ''
    runHook preInstall

    cp -r usr $out
    substituteInPlace $out/share/applications/open-whispr.desktop \
      --replace-fail "/opt/OpenWhispr/open-whispr" "open-whispr"

    mkdir -p $out/opt $out/bin
    cp -r opt/OpenWhispr $out/opt/openwhispr

    # Wrap the real Electron binary (open-whispr-app); force X11 platform so
    # the overlay window works correctly under both X11 and XWayland.
    makeWrapper $out/opt/openwhispr/open-whispr-app $out/bin/open-whispr \
      --add-flags "--ozone-platform=x11" \
      --prefix PATH : ${ydotool}/bin

    runHook postInstall
  '';

  meta = {
    description = "Cross-platform voice-to-text dictation app with AI agents and meeting transcription";
    homepage = "https://github.com/OpenWhispr/openwhispr";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "open-whispr";
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
})
