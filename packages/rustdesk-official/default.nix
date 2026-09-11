# RustDesk — binario oficial precompilado (NO compila desde fuente).
#
# El paquete de nixpkgs usa buildRustPackage (compila ~miles de crates, sin
# caché binaria por ser unfree/libsciter → tardón en cada update que sube su
# versión). Aquí usamos el release oficial .deb de GitHub (1.4.9+ estructura
# stub + plugins: binario 44K + librustdesk.so 47M), lo extraemos con dpkg-deb
# y lo parcheamos contra libs de nixpkgs con autoPatchelfHook. Es descarga +
# patcheo, minutos, nunca una compilación.
#
# Mantenimiento por update de RustDesk:
#   1. cambiar `version`
#   2. recomputar el hash: nix-prefetch-url "https://github.com/rustdesk/rustdesk/releases/download/<v>/rustdesk-<v>-x86_64.deb"
#   3. si la nueva versión cambia de libs, ajustar buildInputs (escucha los
#      errores de auto-patchelf "could not satisfy dependency X")

{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.4.9";
in
pkgs.stdenv.mkDerivation {
  pname = "rustdesk-official";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.deb";
    sha256 = "18zx2bbg21h4ij6fg62cam3cwm3w8rcydysb0ir4300fqi3vli3j";
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.dpkg ];

  # libs que piden el stub de Flutter y librustdesk.so. auto-patchelf reporta
  # "could not satisfy dependency X" si falta alguna al cambiarla.
  buildInputs = with pkgs; [
    gtk3 glib cairo pango atk gdk-pixbuf
    wayland libGL
    gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good
    pam libpulseaudio libX11 libxtst libxcb
  ];

  unpackPhase = ''
    mkdir -p deb
    dpkg-deb -x $src deb/out
  '';

  installPhase = ''
    mkdir -p $out/bin $out/share/rustdesk
    cp -r deb/out/usr/share/rustdesk/* $out/share/rustdesk/
    ln -s $out/share/rustdesk/rustdesk $out/bin/rustdesk
    cp -r deb/out/usr/share/icons/* $out/share/icons/ 2>/dev/null || true
  '';

  dontStrip = true;
}