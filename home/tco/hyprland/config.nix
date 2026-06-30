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
        cat >> $out/theme/rules.conf <<'EOF'

    # --- Rofi Push ---
    windowrule = border_color rgba(00000000), match:class ^(rofi)$

    windowrule {
        name = rofi-push-effects
        match:class = ^(rofi)$

        no_blur = true
        no_shadow = true
        rounding = 64
    }
    EOF
  '';
in
{
  home.file.".config/hypr" = {
    source = hyprConfig;
    force = true;
  };
}
