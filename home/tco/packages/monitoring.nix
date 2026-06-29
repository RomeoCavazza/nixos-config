{ pkgs, ... }:

{
  home.packages = with pkgs; [
    socat
    atop
    bottom
    btop
    glances
    htop
    nvitop
    nvtopPackages.full
  ];
}
