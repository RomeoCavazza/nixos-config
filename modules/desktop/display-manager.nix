_:

{
  imports = [ ./gdm-wallpaper.nix ];

  services.xserver = {
    enable = true;
    xkb.layout = "fr";
  };

  services.displayManager.gdm.enable = true;

  services.displayManager.gdm.customWallpaper = {
    enable = true;
    path = ../../docs/assets/gdm-background.png;
  };
}
