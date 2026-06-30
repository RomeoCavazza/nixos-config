# Renderers: turn the palette attrset (lib/palette.nix) into per-tool colour files.
{ lib }:
let
  hexMap = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  hex2 =
    s: hexMap.${lib.toLower (lib.substring 0 1 s)} * 16 + hexMap.${lib.toLower (lib.substring 1 1 s)};
  noHash = hex: lib.removePrefix "#" hex;
  rgbStr =
    hex:
    let
      h = noHash hex;
    in
    "${toString (hex2 (lib.substring 0 2 h))}, ${toString (hex2 (lib.substring 2 2 h))}, ${
      toString (hex2 (lib.substring 4 2 h))
    }";

  # Catppuccin Mocha names rendered in palette order.
  names = [
    "rosewater"
    "flamingo"
    "pink"
    "mauve"
    "red"
    "maroon"
    "peach"
    "yellow"
    "green"
    "teal"
    "sky"
    "sapphire"
    "blue"
    "lavender"
    "text"
    "subtext1"
    "subtext0"
    "overlay2"
    "overlay1"
    "overlay0"
    "surface2"
    "surface1"
    "surface0"
    "base"
    "mantle"
    "crust"
    "brown"
  ];
in
rec {
  inherit rgbStr noHash;

  # waybar scss variables (consumed via @use '../scss/variables')
  scss =
    p:
    let
      line = n: "$wb-${n}: ${p.${n}};";
    in
    ''
      // --- Waybar Tokens ---

      $wb-accent: ${p.accent};

      // --- Catppuccin Mocha ---
      ${lib.concatStringsSep "\n" (map line names)}

      // --- States ---
      $wb-hover-bg:       rgba(${rgbStr p.accent}, 0.12);
      $wb-taskbar-hover:  rgba(${rgbStr p.accent}, 0.10);
      $wb-taskbar-active: rgba(${rgbStr p.accent}, 0.14);
    '';

  # hyprland design tokens (sourced by conf/tokens.conf consumers)
  hyprland = p: ''
    # --- Design Tokens ---

    $accent = rgba(${noHash p.accent}ff)
  '';
}
