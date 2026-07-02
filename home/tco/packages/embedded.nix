{ pkgs, ... }:

{
  home.packages = with pkgs; [
    arduino-ide
    arduino-cli
    esptool
    minicom
  ];
}
