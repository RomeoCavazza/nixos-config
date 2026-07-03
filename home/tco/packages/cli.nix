{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chafa
    bat
    eza
    fd
    fzf
    glab
    httpie
    jq
    d2
    ripgrep
    ripgrep-all
    tealdeer
    tokei
    trash-cli
    watchexec
    xdg-ninja
    home-manager
    superfile
  ];
}
