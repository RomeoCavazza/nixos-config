{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chafa
    bat
    eza
    fd
    fzf
    jq
    d2
    ripgrep
    home-manager
    superfile
  ];
}
