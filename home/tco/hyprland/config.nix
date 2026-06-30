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
    sed -i '/^layerrule = .*match:namespace \^(rofi)\$/d' $out/theme/rules.conf
  '';
in
{
  home.file.".config/hypr" = {
    source = hyprConfig;
    force = true;
  };
}
