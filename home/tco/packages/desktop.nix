{ pkgs, customPkgs, ... }:

{
  home.packages = with pkgs; [
    customPkgs.wl-ocr
    grim
    slurp
    wev
    wf-recorder
    sway-contrib.grimshot
    libnotify
    desktop-file-utils
    obs-studio
    wshowkeys
    discord
    spotify
  ];
}
