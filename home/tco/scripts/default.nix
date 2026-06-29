{
  config,
  pkgs,
  inputs,
  customPkgs,
  ...
}:

let
  # home/tco/scripts/ is two levels below the repo root.
  repoRoot = ../../..;
in
{
  # --- Vendored in this repo (config/bin/) ---
  home.file.".local/bin/cursor" = {
    source = repoRoot + "/config/bin/cursor";
    executable = true;
  };
  home.file.".local/bin/cursor-toggle" = {
    source = repoRoot + "/config/bin/cursor-toggle";
    executable = true;
  };
  home.file.".local/bin/devin" = {
    source = repoRoot + "/config/bin/devin";
    executable = true;
  };
  home.file.".local/bin/antigravity" = {
    source = repoRoot + "/config/bin/antigravity";
    executable = true;
  };
  home.file.".local/bin/antigravity-ide" = {
    source = repoRoot + "/config/bin/antigravity-ide";
    executable = true;
  };
  home.file.".local/bin/rebuild" = {
    source = repoRoot + "/config/bin/rebuild";
    executable = true;
  };
  home.file.".local/bin/legion-pulse" = {
    source = repoRoot + "/config/bin/legion-pulse";
    executable = true;
  };
  home.file.".local/bin/legion-toggle" = {
    source = repoRoot + "/config/bin/legion-toggle";
    executable = true;
  };

  # --- From the hypr-config flake input ---
  home.file.".local/bin/hypr-plugins-init" = {
    source = "${inputs.hypr-config}/bin/hypr-plugins-init";
    executable = true;
  };
  home.file.".local/bin/hypr-gap-state.sh" = {
    source = "${inputs.hypr-config}/bin/hypr-gap-state.sh";
    executable = true;
  };
  home.file.".local/bin/hypr-overview-toggle" = {
    source = "${inputs.hypr-config}/bin/hypr-overview-toggle";
    executable = true;
  };
  home.file.".local/bin/hypr-close-all" = {
    source = "${inputs.hypr-config}/bin/hypr-close-all";
    executable = true;
  };
  home.file.".local/bin/edex-conky-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-conky-toggle";
    executable = true;
  };
  home.file.".local/bin/edex-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-toggle";
    executable = true;
  };
  home.file.".local/bin/edex-ui-toggle" = {
    source = "${inputs.hypr-config}/bin/edex-toggle";
    executable = true;
  };
  home.file.".local/bin/waybar-toggle" = {
    source = "${inputs.hypr-config}/bin/waybar-toggle";
    executable = true;
  };
  home.file.".local/bin/scss-compile" = {
    source = "${inputs.hypr-config}/bin/scss-compile";
    executable = true;
  };

  # --- Inline scripts ---
  home.file.".local/bin/hypr-layout-toggle" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec hyprctl dispatch canvas:toggle
    '';
  };

  home.file.".local/bin/edex-ui-run" = {
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
}
