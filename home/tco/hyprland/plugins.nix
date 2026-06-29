{ customPkgs, ... }:

let
  mkPlugin = target: source: {
    name = ".local/lib/${target}";
    value = {
      inherit source;
      executable = true;
    };
  };
in
{
  home.file = builtins.listToAttrs [
    (mkPlugin "libhypr-darkwindow.so" "${customPkgs.hypr-darkwindow}/lib/libhypr-darkwindow.so")
    (mkPlugin "hypr-canvas.so" "${customPkgs.hypr-canvas}/lib/hypr-canvas.so")
    (mkPlugin "hyprspace.so" "${customPkgs.hyprspace}/lib/libHyprspace.so")
  ];
}
