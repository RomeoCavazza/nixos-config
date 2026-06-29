{
  pkgs ? import <nixpkgs> { },
}:

(pkgs.buildFHSEnv {
  name = "edex-ui-dev";
  targetPkgs =
    pkgs: with pkgs; [
      nodejs
      python3
      pkg-config
      gnumake
      gcc
      # System dependencies.
      libxshmfence
      nss
      nspr
      alsa-lib
      libdrm
      mesa.drivers # Provides libgbm.so.1.
      libgbm
      mesa
      libGL
      at-spi2-atk
      at-spi2-core
      gtk3
      libxkbcommon
      libX11
      libxcb
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrender
      libXtst
      libXrandr
      pango
      cairo
      expat
      dbus
      glib
      binutils
      gdk-pixbuf
      libpng
      libjpeg
      zlib
      cups
    ];
  runScript = "bash";
}).env
