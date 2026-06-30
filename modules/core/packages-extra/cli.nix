{ pkgs, ... }:

{
  # System CLI: root/recovery basics only. User-facing comfort tools live in
  # home/tco/packages so they do not get declared in both layers.
  environment.systemPackages = with pkgs; [
    bash
    vim
    git # recovery basic: root needs it for flake rebuild + config recovery (tco inherits via system PATH)
    wget
    curl
    lsof
    tree
    fastfetch
    just
  ];
}
