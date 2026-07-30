{ pkgs }:

let
  inherit (pkgs) lib;
  langs = "eng+fra";
in
pkgs.writeShellScriptBin "wl-ocr" ''
  ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" -t ppm - \
    | ${lib.getExe pkgs.tesseract} -l ${langs} - - \
    | ${pkgs.wl-clipboard}/bin/wl-copy
  ${lib.getExe pkgs.libnotify} "OCR" "$(${pkgs.wl-clipboard}/bin/wl-paste)"
''
