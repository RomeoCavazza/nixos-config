{ pkgs, customPkgs, ... }:

{
  home.packages = with pkgs; [
    cbonsai
    cmatrix
    hollywood
    pipes
    sl
    customPkgs.terminal-rain-lightning
  ];
}
