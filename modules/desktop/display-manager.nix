{ pkgs, ... }:

{
  imports = [ ./gdm-wallpaper.nix ];

  services.xserver = {
    enable = true;
    xkb.layout = "fr";
  };

  services.displayManager.gdm.enable = true;

  services.displayManager.gdm.customWallpaper = {
    enable = true;
    path = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/gdm-background.webp";
      sha256 = "sha256-0YdJ4ODElC/cXxvmN6nh7/nybMXyc27+FGSEMmRLUG0=";
    };
  };
}
