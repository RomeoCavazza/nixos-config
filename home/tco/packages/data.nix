{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dbeaver-bin
    influxdb2
  ];
}
