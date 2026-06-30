{ inputs, system }:

let
  pkgs-legacy = import inputs.nixpkgs-legacy {
    inherit system;
    config.allowUnfree = true;
  };
in
[
  (import inputs.rust-overlay)

  (_final: _prev: {
    hyprland = inputs.hyprland.packages.${system}.hyprland;
    hyprland-unwrapped = inputs.hyprland.packages.${system}.hyprland-unwrapped;
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;

    promtail-bin = pkgs-legacy.promtail;
  })
]
