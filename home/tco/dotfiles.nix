{
  config,
  inputs,
  lib,
  locality,
  palette,
  pkgs,
  ...
}:

let
  colors = import ../../lib/colors.nix { inherit lib; };
  conkyPalette = colors.conky palette;

  liveConfig = name: config.lib.file.mkOutOfStoreSymlink "${locality.repoCheckout}/config/${name}";

  rofiTokens = pkgs.writeText "rofi-tokens.rasi" (colors.rofi palette);
  rofiConfig = pkgs.runCommand "rofi-config" { nativeBuildInputs = [ pkgs.perl ]; } ''
    mkdir -p "$out"
    cp -R ${inputs.hypr-config}/rofi/. "$out/"
    chmod -R u+w "$out"

    cp ${rofiTokens} "$out/tokens.rasi"
    sed -i '1i@import "~/.config/rofi/tokens.rasi"\n' "$out/custom/column-tco.rasi"

    substituteInPlace "$out/custom/column-tco.rasi" \
      --replace-fail "#94E2D5" "${palette.accent}" \
      --replace-fail "rgba(148, 226, 213, 14%)" "rgba(${colors.rgbStr palette.accent}, 14%)"

    substituteInPlace "$out/themes/apps-grid.rasi" \
      --replace-fail "rgba(148, 226, 213, 14%)" "rgba(${colors.rgbStr palette.accent}, 14%)" \
      --replace-fail "rgba(255, 90, 90, 12%)" "rgba(${colors.rgbStr palette.red}, 12%)"

    perl -0pi -e 's/(window \{.*?background-color:\s*)transparent;/$1\@columnBg;/s' "$out/custom/column-tco.rasi"
    perl -0pi -e 's/(window \{.*?border-radius:\s*)50px;/$1 64px;/s' "$out/custom/column-tco.rasi"
    perl -0pi -e 's/(element \{.*?border-radius:\s*)50px;/$1 64px;/s' "$out/custom/column-tco.rasi"
    perl -0pi -e 's/(element \{.*?border:\s*)2px;/$1 0;/s' "$out/custom/column-tco.rasi"

    perl -0pi -e 's/(inputbar \{.*?border:\s*)1px;/$1 0;/s' "$out/themes/apps-grid.rasi"
    perl -0pi -e 's/(element \{.*?border:\s*)2px;/$1 0;/s' "$out/themes/apps-grid.rasi"
  '';

  conkyConfig = pkgs.runCommand "conky-config" { } ''
    mkdir -p "$out"
    cp -R ${../../config/conky}/. "$out/"
    chmod -R u+w "$out"
    rm -rf "$out/.git"

    for file in "$out/conky-left.txt" "$out/conky-right.txt"; do
      substituteInPlace "$file" \
        --replace-fail "94e2d5" "${conkyPalette.accent}" \
        --replace-fail "89dceb" "${conkyPalette.graph}" \
        --replace-fail "cdd6f4" "${conkyPalette.text}" \
        --replace-fail "6c7086" "${conkyPalette.muted}" \
        --replace-fail "14313d" "${conkyPalette.graphBase}"
    done
  '';
in
{
  home.file.".config/rofi".source = rofiConfig;
  home.file.".config/foot".source = "${inputs.hypr-config}/foot";
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  home.file.".config/conky".source = conkyConfig;
  home.file.".config/nvim".source = liveConfig "nvim";
  home.file.".config/doom".source = liveConfig "doom";

  xdg.configFile."eDEX-UI/settings.json".source = "${inputs.hypr-config}/edex/settings.json";
}
