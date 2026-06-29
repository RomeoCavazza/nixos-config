{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    rofi
    waybar
    networkmanagerapplet
    nemo
    procps
  ];

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  programs.thunar.enable = true;
}
