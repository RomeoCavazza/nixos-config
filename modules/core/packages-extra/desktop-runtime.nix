{ pkgs, ... }:

{
  # System desktop runtime: libraries and services needed by the graphical
  # stack. User themes/session helpers live in Home Manager.
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    fuse2
    fuse3
    libxshmfence
    kitty
    foot
    firefox
    google-chrome
    wl-clipboard
    pavucontrol
    networkmanager
    polkit_gnome
    nix-ld
    mesa
    libglvnd
    libdrm
  ];
}
