{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bash
    vim
    neovim
    git
    wget
    curl
    jq
    lsof
    tree
    ripgrep
    fd
    fzf
    fastfetch
    btop
    htop
    just
    eza
  ];
}
