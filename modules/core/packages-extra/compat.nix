{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    steam-run
    wineWow64Packages.stable
    winetricks
  ];
}
