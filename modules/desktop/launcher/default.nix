{ pkgs, ... }:

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
  services.tumbler.enable = true;
}
