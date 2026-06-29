{ pkgs, inputs, ... }:

let
  waybarConfig =
    pkgs.runCommand "waybar-config"
      {
        nativeBuildInputs = [ pkgs.dart-sass ];
      }
      ''
            mkdir -p $out source/waybar source/scss

            cp -R ${inputs.hypr-config}/waybar/. $out/
            chmod -R u+w $out
            rm -f $out/style.css

            cp ${inputs.hypr-config}/waybar/style.scss source/waybar/style.scss
            cp -R ${inputs.hypr-config}/scss/. source/scss/

        sass \
          --no-source-map \
          --no-charset \
          --style=expanded \
          source/waybar/style.scss \
          $out/style.css
      '';
in
{
  home.file.".config/waybar".source = waybarConfig;
}
