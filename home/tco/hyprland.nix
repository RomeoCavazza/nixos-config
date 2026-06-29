{
  pkgs,
  inputs,
  customPkgs,
  ...
}:

let
  hyprConfig = pkgs.runCommand "hypr-config-canvas" { } ''
          cp -R ${inputs.hypr-config}/. $out/
          chmod -R u+w $out

          substituteInPlace $out/hyprland.conf \
            --replace-fail 'bind = $mod, F, togglefloating' 'bind = $mod, F, canvas:float' \
            --replace-fail 'bind = $mod, left,  movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up,    movefocus, u
    bind = $mod, down,  movefocus, d' '# Canvas navigation
    bind = $mod, left,  canvas:nav, left
    bind = $mod, right, canvas:nav, right
    bind = $mod, up,    canvas:nav, up
    bind = $mod, down,  canvas:nav, down' \
            --replace-fail '# Layout toggle (Simple, decoupled)
    bind = $mod, Z, exec, $HOME/.local/bin/hypr-layout-toggle
    bind = $mod, B, exec, $HOME/.local/bin/waybar-toggle
    bind = $mod, M, exec, $HOME/.local/bin/cursor-toggle
    # Hypr-canvas binds
    bind = $mod, R, canvas:reset,
    bind = $mod ALT SHIFT, left,  canvas:pan, left
    bind = $mod ALT SHIFT, right, canvas:pan, right
    bind = $mod ALT SHIFT, up,    canvas:pan, up
    bind = $mod ALT SHIFT, down,  canvas:pan, down
    bind = $mod, minus,           canvas:zoom, out
    bind = $mod, equal,           canvas:zoom, in' '# Canvas mode
    bind = $mod, Z, canvas:toggle
    bind = $mod, X, canvas:center
    bind = $mod, R, canvas:home
    bind = $mod, B, exec, $HOME/.local/bin/waybar-toggle
    bind = $mod, M, exec, $HOME/.local/bin/cursor-toggle

    # Manual viewport nudge
    bind = $mod ALT SHIFT, left,  canvas:pan, left
    bind = $mod ALT SHIFT, right, canvas:pan, right
    bind = $mod ALT SHIFT, up,    canvas:pan, up
    bind = $mod ALT SHIFT, down,  canvas:pan, down

    # Zoom
    bind = $mod, minus, canvas:zoom, out
    bind = $mod, equal, canvas:zoom, in

    # Canvas extras
    bind = $mod, W, canvas:overview
    bind = $mod, P, canvas:pin'
  '';
in
{
  home.file.".config/hypr" = {
    source = hyprConfig;
    force = true;
  };

  home.file.".local/lib/libhypr-darkwindow.so" = {
    source = "${customPkgs.hypr-darkwindow}/lib/libhypr-darkwindow.so";
    executable = true;
  };

  home.file.".local/lib/hypr-canvas.so" = {
    source = "${customPkgs.hypr-canvas}/lib/hypr-canvas.so";
    executable = true;
  };

  home.file.".local/lib/hyprspace.so" = {
    source = "${customPkgs.hyprspace}/lib/libHyprspace.so";
    executable = true;
  };
}
