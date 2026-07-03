{ config, pkgs, ... }:

{
  # GTK is owned by adw-gtk3-dark (neutral gray + blue accent), NOT Stylix
  # (whose Catppuccin Mocha turned everything mauve). Uniform across every GTK
  # app, Nemo included — no per-app CSS overrides.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.colorScheme = "dark";
    gtk4.theme = config.gtk.theme;
  };
}
