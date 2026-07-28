{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nautilus-python,
  python3,
}:

# Installing this package is not enough on its own: nautilus-python has to be in
# environment.systemPackages too, so that NAUTILUS_4_EXTENSION_DIR (set by the
# GNOME module to ${config.system.path}/lib/nautilus/extensions-4) contains its
# loader. The loader then finds this extension by scanning XDG_DATA_DIRS for
# share/nautilus-python/extensions, which the GNOME module links via
# environment.pathsToLink. Without GNOME, set NAUTILUS_4_EXTENSION_DIR and that
# pathsToLink entry yourself.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "nautilus-unicode-tag-columns";
  version = "0-unstable-2026-07-27";

  src = fetchFromGitHub {
    owner = "wasbeer";
    repo = "nautilus-unicode-tag-columns";
    rev = "d148591b18790af2ba0d332ecec7724a4ced9db9";
    hash = "sha256-y1yVBzJZyRq4NL0W87B3GcgNjYC5/tgA7kh3tFHpaoI=";
  };

  buildInputs = [
    nautilus-python
    python3.pkgs.pygobject3
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    make install PREFIX=$out
    # `make install` creates __pycache__ unconditionally; nothing is byte-compiled here
    rmdir $out/share/nautilus-python/extensions/__pycache__
    runHook postInstall
  '';

  meta = {
    description = "Nautilus extension to tag files and folders with unicode emoji and show them in a column";
    homepage = "https://github.com/wasbeer/nautilus-unicode-tag-columns";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
})
