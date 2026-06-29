{ inputs, system }:

let
  # Secondary nixpkgs channels, used only to backport a handful of packages
  # into the main package set via the overlay below.
  mkPkgs = src: import src {
    inherit system;
    config.allowUnfree = true;
  };

  pkgs-stable = mkPkgs inputs.nixpkgs-stable;
  pkgs-portal = mkPkgs inputs.nixpkgs-portal;
  pkgs-legacy = mkPkgs inputs.nixpkgs-legacy;
in
[
  (import inputs.rust-overlay)

  (final: prev: {
    hyprland = inputs.hyprland.packages.${system}.hyprland;
    hyprland-unwrapped = inputs.hyprland.packages.${system}.hyprland-unwrapped;
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;

    promtail-bin = pkgs-legacy.promtail;

    guix = pkgs-stable.guix;
    xdg-desktop-portal = pkgs-portal.xdg-desktop-portal;
    xdg-desktop-portal-gtk = pkgs-portal.xdg-desktop-portal-gtk;
    xdg-desktop-portal-gnome = pkgs-portal.xdg-desktop-portal-gnome;
  })
]
