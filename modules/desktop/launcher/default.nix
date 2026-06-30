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
  # Thumbnailer for nemo (video/pdf). Replaces the unused thunar file manager,
  # which was only pulled in for its services; nemo is the actual $fileManager.
  services.tumbler.enable = true;
}
