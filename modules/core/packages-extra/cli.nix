{ pkgs, ... }:

{
  # System CLI: root/recovery basics only. User-facing comfort tools live in
  # home/tco/packages so they do not get declared in both layers.
  environment.systemPackages = with pkgs; [
    bash
    vim
    git
    wget
    curl
    jq
    lsof
    tree
    fastfetch
    just
  ];
}
