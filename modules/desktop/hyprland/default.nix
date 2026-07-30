{ lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  security.wrappers.Hyprland.capabilities = lib.mkForce "";
}
