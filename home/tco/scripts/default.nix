{
  config,
  pkgs,
  inputs,
  customPkgs,
  ...
}:

let
  # home/tco/scripts/ is three levels below the repo root.
  repoRoot = ../../..;
  mkBin = name: source: {
    inherit name;
    value = {
      inherit source;
      executable = true;
    };
  };

  mkLocalBin = name: mkBin ".local/bin/${name}" (repoRoot + "/config/bin/${name}");
  mkInputBin = name: sourceName: mkBin ".local/bin/${name}" "${inputs.hypr-config}/bin/${sourceName}";

  vendoredBins = [
    "cursor"
    "cursor-toggle"
    "devin"
    "antigravity"
    "antigravity-ide"
    "rebuild"
    "legion-pulse"
    "legion-toggle"
  ];

  hyprConfigBins = [
    "hypr-plugins-init"
    "hypr-gap-state.sh"
    "hypr-overview-toggle"
    "hypr-close-all"
    "edex-conky-toggle"
    "edex-toggle"
    "waybar-toggle"
    "scss-compile"
  ];

  # Kept as a distinct command name, but intentionally backed by the same
  # upstream toggle script as edex-toggle.
  hyprConfigAliases = {
    "edex-ui-toggle" = "edex-toggle";
  };
in
{
  home.file =
    builtins.listToAttrs (
      map mkLocalBin vendoredBins
      ++ map (name: mkInputBin name name) hyprConfigBins
      ++ builtins.attrValues (
        builtins.mapAttrs (name: sourceName: mkInputBin name sourceName) hyprConfigAliases
      )
    )
    // {
      # --- Inline scripts ---
      ".local/bin/edex-ui-run" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail
          export SHELL="''${SHELL:-${pkgs.bashInteractive}/bin/bash}"
          export TERM="''${TERM:-xterm-256color}"
          export COLORTERM="''${COLORTERM:-truecolor}"
          export PATH="''${PATH:-${config.home.profileDirectory}/bin:/run/current-system/sw/bin}"
          export LD_LIBRARY_PATH="${pkgs.libxshmfence}/lib:''${LD_LIBRARY_PATH:-}"
          exec ${pkgs.appimage-run}/bin/appimage-run ${customPkgs.edex-ui-appimage} \
            --no-sandbox --disable-gpu-sandbox \
            --ozone-platform=x11 --disable-features=UseOzonePlatform "$@"
        '';
      };
    };
}
