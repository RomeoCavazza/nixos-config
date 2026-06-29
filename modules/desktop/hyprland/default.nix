{ lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hyprland is started from the user session; drop the wrapper's file capabilities.
  security.wrappers.Hyprland.capabilities = lib.mkForce "";
}
