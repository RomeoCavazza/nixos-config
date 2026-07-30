{ pkgs, inputs }:

let
  hyprland-pkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  hyprchroma-src = pkgs.lib.cleanSource inputs.hyprchroma;
in
pkgs.stdenv.mkDerivation {
  pname = "hypr-darkwindow";
  version = "3.4.1-v055";
  srcs = [ ];
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;
  buildPhase = ''
    g++ -shared -fPIC -std=c++2b -O2 \
      $(pkg-config --cflags hyprland pixman-1 libdrm) \
      -DWLR_USE_UNSTABLE \
      ${hyprchroma-src}/src/main.cpp \
      -o libhypr-darkwindow.so
  '';
  installPhase = ''
    mkdir -p $out/lib
    cp libhypr-darkwindow.so $out/lib/
  '';
  meta.description = "Hyprchroma v3.4.1-v055 — unified adaptive tint release";
}
