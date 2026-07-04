{
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

  rofiTokens = pkgs.writeText "rofi-tokens.rasi" (colors.rofi palette);
  rofiConfig = pkgs.runCommand "rofi-config" { } ''
    mkdir -p "$out"
    cp -R ${inputs.hypr-config}/rofi/. "$out/"
    chmod -R u+w "$out"

    cp ${rofiTokens} "$out/tokens.rasi"

    cat >> "$out/custom/column-tco.rasi" <<EOF

    @import "~/.config/rofi/tokens.rasi"

    * {
      c-teal:        @accent;
      c-selected-bg: @selectedBg;
      text-color:    @accent;
    }

    window {
      background-color: @columnBg;
      border-radius:    64px;
    }

    element {
      border-radius:    64px;
      border:           0;
    }
    EOF

    cat >> "$out/themes/apps-grid.rasi" <<EOF

    inputbar {
      border: 0;
    }

    element {
      border: 0;
    }

    element selected {
      background-color: @selectedBg;
    }

    element.urgent,
    element selected.urgent {
      background-color: @urgentBg;
    }
    EOF
  '';

  conkyConfig = pkgs.runCommand "conky-config" { } ''
    if [ ! -f ${inputs.conky-config}/conky-left.txt ] || [ ! -f ${inputs.conky-config}/conky-right.txt ]; then
      echo "ERROR: conky-config input is missing expected panel files." >&2
      exit 1
    fi
    mkdir -p "$out"
    cp -R ${inputs.conky-config}/. "$out/"
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

  edexSettings = pkgs.runCommand "edex-settings.json" { } ''
    cp ${inputs.hypr-config}/edex/settings.json "$out"
    substituteInPlace "$out" \
      --replace-fail '"/home/tco"' '"${locality.homeDirectory}"'
  '';

  footPalette = colors.foot palette;
  footConfig = pkgs.runCommand "foot-config" { } ''
    mkdir -p "$out"
    cp -R ${inputs.hypr-config}/foot/. "$out/"
    chmod -R u+w "$out"

    substituteInPlace "$out/foot.ini" \
      --replace-fail "1e1e2e" "${footPalette.background}" \
      --replace-fail "cdd6f4" "${footPalette.foreground}" \
      --replace-fail "45475a" "${footPalette.regular0}" \
      --replace-fail "f38ba8" "${footPalette.regular1}" \
      --replace-fail "a6e3a1" "${footPalette.regular2}" \
      --replace-fail "f9e2af" "${footPalette.regular3}" \
      --replace-fail "89b4fa" "${footPalette.regular4}" \
      --replace-fail "f5c2e7" "${footPalette.regular5}" \
      --replace-fail "94e2d5" "${footPalette.regular6}" \
      --replace-fail "bac2de" "${footPalette.regular7}" \
      --replace-fail "585b70" "${footPalette.bright0}" \
      --replace-fail "a6adc8" "${footPalette.bright7}"
  '';
in
{
  home.file.".config/rofi".source = rofiConfig;
  home.file.".config/conky".source = conkyConfig;
  home.file.".config/foot".source = footConfig;
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  xdg.configFile."eDEX-UI/settings.json".source = edexSettings;
  home.file.".config/nvim".source = inputs.nvim-config;
  home.file.".config/doom".source = inputs.doom-config;
}
