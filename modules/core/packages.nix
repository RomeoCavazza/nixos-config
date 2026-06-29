{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    unrar
    usbutils
    pciutils
  ];
}
