{ pkgs, ... }:

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    curl
    glib
    gtk3
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    gdk-pixbuf
    dbus
    expat
    udev
    alsa-lib
    cups
    nspr
    nss
    libxshmfence
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libxkbfile
    libxkbcommon
    mesa
    libgbm
    libglvnd
    libdrm
  ];
}
