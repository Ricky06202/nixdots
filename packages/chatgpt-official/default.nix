{ pkgs }:

let
  version = "26.1103.32239";
  inherit (pkgs) lib;
  runtimeLibraries = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    graphite2
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    tpm2-tss
    udev
    wayland
    xz
  ];

  # Electron/Node and native modules must remain byte-for-byte intact. Use an
  # FHS runtime instead of autoPatchelf; the upstream Nix packaging documents
  # startup failures from rewriting the main ELF.
  chatgptUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-unwrapped";
    inherit version;

    src = pkgs.fetchurl {
      name = "chatgpt_amd64.deb";
      # Exact URL observed on OpenAI's Linux download page; the fixed hash pins
      # the downloaded artifact even though this endpoint is named /latest.
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      hash = "sha256-GMEIgI6ixS+42/ktM2LSd0HjOCxYkb1K6QOptXgTZO8=";
    };

    nativeBuildInputs = [ pkgs.dpkg ];

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib" "$out/share"
      cp -a usr/lib/chatgpt "$out/lib/"
      cp -a usr/share/applications usr/share/pixmaps "$out/share/"

      # The current .deb moved Tectonic to resources/tectonic. Replace only
      # that helper with nixpkgs' CLI; leave Electron and its native modules
      # untouched.
      tectonic="$out/lib/chatgpt/resources/tectonic/tectonic"
      rm "$tectonic"
      ln -s ${pkgs.tectonic-unwrapped}/bin/tectonic "$tectonic"

      # Keep Codex deep-links and file associations, but leave HTTP(S) with
      # Librewolf, the user's configured default browser.
      substituteInPlace "$out/share/applications/chatgpt.desktop" \
        --replace-fail "x-scheme-handler/http;" "" \
        --replace-fail "x-scheme-handler/https;" ""
      runHook postInstall
    '';
  };

  launcher = pkgs.writeShellScript "chatgpt-launcher" ''
    if [ -z "''${CODEX_TECTONIC_PATH:-}" ]; then
      export CODEX_TECTONIC_PATH="${chatgptUnwrapped}/lib/chatgpt/resources/tectonic/tectonic"
    fi
    exec ${chatgptUnwrapped}/lib/chatgpt/ChatGPT \
      ''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true} \
      "$@"
  '';
in
pkgs.buildFHSEnv {
  name = "chatgpt";
  targetPkgs = _: runtimeLibraries ++ (with pkgs; [ git xdg-utils ]);
  runScript = launcher;

  extraInstallCommands = ''
    mkdir -p "$out/share"
    cp -a ${chatgptUnwrapped}/share/applications "$out/share/"
    cp -a ${chatgptUnwrapped}/share/pixmaps "$out/share/"
  '';

  passthru = {
    unwrapped = chatgptUnwrapped;
    debianPackageSha256 = "18c108808ea2c52fb8dbf92d3362d27741e3382c5891bd4ae903a9b5781364ef";
  };

  meta = {
    description = "Official ChatGPT desktop application for Linux";
    homepage = "https://chatgpt.com/download/";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
