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

  rofi = p: ''
    * {
      accent:     ${p.accent};
      selectedBg: rgba(${rgbStr p.accent}, 14%);

      fg0:        rgba(255, 255, 255, 95%);
      fgDim:      rgba(255, 255, 255, 45%);

      scrim:      rgba(18, 20, 24, 22%);
      field:      rgba(255, 255, 255, 10%);
      fieldEdge:  rgba(255, 255, 255, 16%);

      hover:      rgba(255, 255, 255, 14%);
      urgentBg:   rgba(${rgbStr p.red}, 12%);

      columnBg:   rgba(${rgbStr p.surface0}, 18%);
      columnEdge: rgba(${rgbStr p.accent}, 22%);
    }
  '';

  conky = p: {
    accent = noHash p.accent;
    graph = noHash p.sky;
    text = noHash p.text;
    muted = noHash p.overlay0;
    graphBase = "14313d";
  };

  foot = p: {
    background = noHash p.base;
    foreground = noHash p.text;
    regular0 = noHash p.surface1;
    regular1 = noHash p.red;
    regular2 = noHash p.green;
    regular3 = noHash p.yellow;
    regular4 = noHash p.blue;
    regular5 = noHash p.pink;
    regular6 = noHash p.accent;
    regular7 = noHash p.subtext1;
    bright0 = noHash p.surface2;
    bright1 = noHash p.red;
    bright2 = noHash p.green;
    bright3 = noHash p.yellow;
    bright4 = noHash p.blue;
    bright5 = noHash p.pink;
    bright6 = noHash p.accent;
    bright7 = noHash p.subtext0;
  };

  starship = p: {
    format = "[░▒▓](${p.accent})[  ](bg:${p.accent} fg:${p.crust})[](fg:${p.accent} bg:${p.surface0})$directory[](fg:${p.surface0} bg:none)$character";
    directory = {
      style = "fg:${p.accent} bg:${p.surface0}";
      format = "[ $path ]($style)";
      truncation_length = 3;
      truncation_symbol = "…/";
    };
    character = {
      success_symbol = "[ ❯](bold ${p.accent})";
      error_symbol = "[ ❯](bold ${p.red})";
    };
  };

  scss =
    p:
    let
      line = n: "$wb-${n}: ${p.${n}};";
    in
    ''
      $wb-accent: ${p.accent};

      ${lib.concatStringsSep "\n" (map line names)}

      $wb-hover-bg:       rgba(${rgbStr p.accent}, 0.12);
      $wb-taskbar-hover:  rgba(${rgbStr p.accent}, 0.10);
      $wb-taskbar-active: rgba(${rgbStr p.accent}, 0.14);
    '';

  hyprland = p: ''
    $accent = rgba(${noHash p.accent}ff)
  '';

  grafanaMocha = p: ''
    local mocha = {
      base: '${p.base}',
      mantle: '${p.mantle}',
      crust: '${p.crust}',
      surface0: '${p.surface0}',
      surface1: '${p.surface1}',
      surface2: '${p.surface2}',

      text: '${p.text}',
      subtext1: '${p.subtext1}',
      subtext0: '${p.subtext0}',
      overlay2: '${p.overlay2}',

      blue: '${p.blue}',
      sapphire: '${p.sapphire}',
      sky: '${p.sky}',
      teal: '${p.teal}',
      lavender: '${p.lavender}',
      mauve: '${p.mauve}',
      pink: '${p.pink}',
      flamingo: '${p.flamingo}',

      green: '${p.green}',
      yellow: '${p.yellow}',
      peach: '${p.peach}',
      maroon: '${p.maroon}',
      red: '${p.red}',
    };
  '';
}
