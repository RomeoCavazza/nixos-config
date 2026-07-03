{ config, pkgs, ... }:

{
  # GTK is owned by Adwaita-dark (the pre-Stylix look: lighter blue-gray, and
  # recognised by Nemo), NOT Stylix — whose Catppuccin Mocha turned everything
  # mauve. Uniform across every GTK app, no per-app CSS overrides.
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
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
