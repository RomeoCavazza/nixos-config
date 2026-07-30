{
  pkgs,
  lib,
  inputs,
  palette,
  ...
}:

let
  colors = import ../../../lib/colors.nix { inherit lib; };
  hyprConfig = pkgs.runCommand "hypr-config" { } ''
    cp -R ${inputs.hypr-config} $out
    chmod -R u+w $out
    cp ${pkgs.writeText "tokens.conf" (colors.hyprland palette)} $out/conf/tokens.conf
  '';
in
{
  home.file.".config/hypr" = {
    source = hyprConfig;
    force = true;
  };
}
