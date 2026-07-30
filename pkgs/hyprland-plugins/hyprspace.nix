{ pkgs, inputs }:

inputs.hyprspace.packages.${pkgs.stdenv.hostPlatform.system}.Hyprspace
