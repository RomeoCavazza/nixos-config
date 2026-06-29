{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hyprlock
    hypridle
    brightnessctl
    playerctl
    appimage-run
  ];
}
