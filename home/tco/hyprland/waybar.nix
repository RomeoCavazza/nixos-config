{
  pkgs,
  lib,
  inputs,
  palette,
  ...
}:

let
  colors = import ../../../lib/colors.nix { inherit lib; };
  scssVariables = pkgs.writeText "waybar-variables.scss" (colors.scss palette);
  waybarConfig =
    pkgs.runCommand "waybar-config"
      {
        nativeBuildInputs = [
          pkgs.dart-sass
          pkgs.makeWrapper
        ];
      }
      ''
            mkdir -p $out source/waybar source/scss

            cp -R ${inputs.hypr-config}/waybar/. $out/
            chmod -R u+w $out
            rm -f $out/style.css

            cp ${inputs.hypr-config}/waybar/style.scss source/waybar/style.scss
            cp -R ${inputs.hypr-config}/scss/. source/scss/
            chmod -R u+w source
            cp ${scssVariables} source/scss/_variables.scss

        sass \
          --no-source-map \
          --no-charset \
          --style=expanded \
          source/waybar/style.scss \
          $out/style.css

        patchShebangs $out/WaybarCava.sh
        wrapProgram $out/WaybarCava.sh \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.bash
              pkgs.cava
              pkgs.coreutils
              pkgs.gawk
              pkgs.gnused
              pkgs.procps
            ]
          }
      '';
in
{
  home.file.".config/waybar".source = waybarConfig;

  systemd.user.services.waybar = {
    Unit = {
      Description = "Highly customizable Wayland bar for Hyprland";
      Documentation = "https://github.com/Alexays/Waybar/wiki";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar -c %h/.config/waybar/config.jsonc -s %h/.config/waybar/style.css";
      ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR2 $MAINPID";
      Restart = "always";
      RestartSec = "100ms";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
