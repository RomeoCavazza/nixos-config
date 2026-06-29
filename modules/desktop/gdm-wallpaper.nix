{ pkgs, lib, config, ... }:

let
  cfg = config.services.displayManager.gdm.customWallpaper;
in
{
  options.services.displayManager.gdm.customWallpaper = {
    enable = lib.mkEnableOption "Custom GDM Wallpaper";
    path = lib.mkOption {
      type = lib.types.path;
      description = "Path to the wallpaper image";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        gnome-shell = prev.gnome-shell.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            workdir=$(mktemp -d)
            resource=$out/share/gnome-shell/gnome-shell-theme.gresource
            
            # 1. Extract every file from the original gresource.
            for r in $(${prev.glib.dev}/bin/gresource list $resource); do
              mkdir -p "$workdir$(dirname $r)"
              filename=$(echo $r | sed 's|^/org/gnome/shell/theme/||')
              ${prev.glib.dev}/bin/gresource extract $resource $r > "$workdir/$filename"
            done
            
            # 2. Copy the custom image.
            cp ${cfg.path} "$workdir/custom-background.png"
            
            # 3. Patch every CSS file found in the theme.
            # Target #lockDialogGroup, .login-screen, and .login-background.
            for css in "$workdir"/*.css; do
              echo "Patching $css..."
              echo "
              #lockDialogGroup, .login-mask, .login-screen, .login-background, .login-dialog-container {
                background-image: url('custom-background.png') !important;
                background-size: cover !important;
                background-repeat: no-repeat !important;
                background-position: center !important;
                background-color: #000000 !important;
              }
              .login-dialog {
                background-color: transparent !important;
              }
              #panel {
                background-color: transparent !important;
                background: none !important;
                box-shadow: none !important;
                border: none !important;
              }
              .panel-corner {
                background-color: transparent !important;
                -panel-corner-radius: 0px !important;
                -panel-corner-background-color: transparent !important;
              }" >> "$css"
            done
            
            # 4. Generate the full XML file.
            echo '<?xml version="1.0" encoding="UTF-8"?>' > "$workdir/theme.gresource.xml"
            echo '<gresources><gresource prefix="/org/gnome/shell/theme">' >> "$workdir/theme.gresource.xml"
            for f in $(cd "$workdir" && find . -type f -not -name "theme.gresource.xml"); do
              clean_f=$(echo $f | sed 's|^\./||')
              echo "  <file>$clean_f</file>" >> "$workdir/theme.gresource.xml"
            done
            echo '</gresource></gresources>' >> "$workdir/theme.gresource.xml"
            
            # 5. Recompile everything.
            ${prev.glib.dev}/bin/glib-compile-resources --target="$workdir/new.gresource" --sourcedir="$workdir" "$workdir/theme.gresource.xml"
            
            # 6. Replace the original file.
            cp "$workdir/new.gresource" $resource
            rm -rf $workdir
          '';
        });
      })
    ];
  };
}
