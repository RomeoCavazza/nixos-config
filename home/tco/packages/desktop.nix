{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
