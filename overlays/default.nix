{ inputs, system }:

let
  # Promtail was removed from newer nixpkgs with the Loki 3 transition. Keep a
  # narrow legacy package set until this host migrates to Grafana Alloy.
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
