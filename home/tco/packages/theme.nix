{ pkgs, ... }:

{
  home.packages = with pkgs; [
    papirus-icon-theme
    swaynotificationcenter
    cava
    cool-retro-term
    nerd-fonts.symbols-only
    hyprcursor
    rose-pine-hyprcursor
    nerd-fonts.jetbrains-mono
    bibata-cursors
    conky
    adw-gtk3
    gnome-themes-extra
    pywal
    wpgtk
    qt6Packages.qtbase
    qt6Packages.qt6ct
    qt6Packages.qttools
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
  ];
}
