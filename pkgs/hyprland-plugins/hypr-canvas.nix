{ pkgs, inputs }:

let
  hyprland-pkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  hypr-canvas-src = pkgs.lib.cleanSource inputs.hypr-canvas;
in
pkgs.stdenv.mkDerivation {
  pname = "hypr-canvas";
  version = "0.1.0-alpha";

  srcs = [ ];
  dontUnpack = true;

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;

  buildPhase = ''
    g++ -shared -fPIC -std=c++2b -O2 \
      $(pkg-config --cflags hyprland pixman-1 libdrm) \
      ${hypr-canvas-src}/src/main.cpp ${hypr-canvas-src}/src/canvas.cpp \
      -o hypr-canvas.so
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp hypr-canvas.so $out/lib/
  '';

  meta.description = "Infinite canvas plugin for Hyprland";
}
