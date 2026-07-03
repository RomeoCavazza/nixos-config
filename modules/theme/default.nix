{
  lib,
  pkgs,
  palette,
  typography,
  ...
}:

{
  options.theme = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Human-readable theme identifier for this workstation.";
    };

    accent = lib.mkOption {
      type = lib.types.str;
      default = palette.accent;
      description = "Primary accent colour from theme.palette.";
    };

    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = palette;
      description = "Shared colour palette consumed by desktop and terminal modules.";
    };

    typography = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = typography;
      description = "Shared font tokens consumed by Home Manager modules.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.path;
      default = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/gdm-background.webp";
        sha256 = "sha256-0YdJ4ODElC/cXxvmN6nh7/nybMXyc27+FGSEMmRLUG0=";
      };
      description = "Primary wallpaper asset used by display-facing modules.";
    };
  };
}
