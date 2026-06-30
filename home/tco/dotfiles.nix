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
  rofiConfig = pkgs.runCommand "rofi-config" { } ''
    mkdir -p "$out"
    cp -R ${inputs.hypr-config}/rofi/. "$out/"
    chmod -R u+w "$out"

    cp ${rofiTokens} "$out/tokens.rasi"

    cat >> "$out/custom/column-tco.rasi" <<EOF

    /* --- Declarative NixOS Overrides --- */
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

    /* --- Declarative NixOS Overrides --- */
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
    if [ -z "$(ls -A ${../../config/conky} 2>/dev/null)" ]; then
      echo "ERROR: config/conky submodule is empty! Run 'git submodule update --init --recursive'." >&2
      exit 1
    fi
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

  edexSettings = pkgs.runCommand "edex-settings.json" { } ''
    sed -e 's|"/home/tco"|"${locality.homeDirectory}"|g' \
        -e 's|"en-US"|"fr-FR"|g' \
        ${inputs.hypr-config}/edex/settings.json > $out
  '';
in
{
  # ---------------------------------------------------------------------------
  # 1. Compiled Store Derivations (Requiring token injection or build step)
  # ---------------------------------------------------------------------------
  home.file.".config/rofi".source = rofiConfig;
  home.file.".config/conky".source = conkyConfig;
  home.file.".config/foot".source = "${inputs.hypr-config}/foot";
  home.file.".config/swappy/config".source = "${inputs.hypr-config}/swappy/config";
  xdg.configFile."eDEX-UI/settings.json".source = edexSettings;

  # ---------------------------------------------------------------------------
  # 2. Live Out-of-Store Symlinks (Zero rebuild needed for rapid iteration)
  # ---------------------------------------------------------------------------
  home.file.".config/nvim".source = liveConfig "nvim";
  home.file.".config/doom".source = liveConfig "doom";
}
