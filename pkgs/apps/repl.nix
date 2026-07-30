{ pkgs }:

let
  repl = ../../lib/repl.nix;
  example = command: desc: ''\n[33m ${command}[0m - ${desc}'';
in
pkgs.writeShellScriptBin "repl" ''
  case "$1" in
    "-h" | "--help" | "help")
      printf "%b\n\e[4mUsage\e[0m: \
        ${example "repl" "Loads the system flake if available."} \
        ${example "repl /path/to/flake.nix" "Loads the specified flake."}\n"
      ;;
    *)
      if [ -z "$1" ]; then
        nix repl --expr 'import ${repl} { }'
      else
        FLAKE_PATH=$(${pkgs.coreutils}/bin/readlink -f "$1" | ${pkgs.gnused}/bin/sed 's|/flake.nix||')
        nix repl --expr "import ${repl} { flakePath = \"$FLAKE_PATH\"; }"
      fi
      ;;
  esac
''
