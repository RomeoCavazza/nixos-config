{ pkgs, ... }:

{
  home.packages = with pkgs; [
    papirus-icon-theme
    swaynotificationcenter
    cava
    cool-retro-term
    hyprcursor
    rose-pine-hyprcursor
    bibata-cursors
    conky
    adw-gtk3
    gnome-themes-extra
    qt6Packages.qtbase
    qt6Packages.qt6ct
    qt6Packages.qttools
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
  ];
}
