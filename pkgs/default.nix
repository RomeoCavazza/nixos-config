{ pkgs, inputs }:

# User-scoped custom derivations, imported as `customPkgs` in home.nix.
# Kept out of the global overlay since these are only consumed by the user layer.
{
  hypr-canvas = import ./hyprland-plugins/hypr-canvas.nix { inherit pkgs inputs; };
  hypr-darkwindow = import ./hyprland-plugins/hypr-darkwindow.nix { inherit pkgs inputs; };
  hyprspace = import ./hyprland-plugins/hyprspace.nix { inherit pkgs inputs; };

  terminal-rain-lightning = import ./apps/terminal-rain.nix { inherit pkgs; };
  edex-ui-appimage = import ./apps/edex-appimage.nix { inherit pkgs; };
  edex-ui-dev = import ./apps/edex.nix { inherit pkgs; };
  cursor = import ./apps/cursor.nix { inherit pkgs; };
}
