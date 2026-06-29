{ config, ... }:

{
  imports = [
    ./modules/apps/cad.nix
    ./modules/apps/embedded.nix
    ./modules/apps/data.nix
    ./scripts
    ./packages.nix
    ./shell.nix
    ./gtk.nix
    ./apps.nix
    ./hyprland.nix
    ./waybar.nix
    ./dotfiles.nix
  ];

  home.username = "tco";
  home.homeDirectory = "/home/tco";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionPath = [
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    PATH = "$HOME/.local/bin:$PATH";
    XDG_DATA_DIRS = "$HOME/.local/share:$XDG_DATA_DIRS";
    ELECTRON_OZONE_PLATFORM_HINT = "x11";
  };

  xdg.enable = true;
  xdg.mime.enable = true;
}
