{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    i2c-tools
    iw
    ethtool
    pciutils
    usbutils
    openhantek6022
  ];
}
