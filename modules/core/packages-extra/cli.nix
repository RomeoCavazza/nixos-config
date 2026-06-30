{ pkgs, ... }:

{
  # --- System CLI ---
  environment.systemPackages = with pkgs; [
    bash
    vim
    git
    wget
    curl
    lsof
    tree
    fastfetch
    just
  ];
}
