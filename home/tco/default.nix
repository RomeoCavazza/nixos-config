{ config, locality, ... }:

{
  imports = [
    ./scripts
    ./packages
    ./shell.nix
    ./gtk.nix
    ./apps.nix
    ./emacs.nix
    ./hyprland
    ./dotfiles.nix
  ];

  home.username = locality.user;
  home.homeDirectory = locality.homeDirectory;
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionPath = [
    "${config.home.homeDirectory}/.lmstudio/bin"
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  home.sessionVariables = {
    NIXOS_CONFIG_REPO = locality.repoCheckout;
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XDG_DATA_DIRS = "$HOME/.local/share:$XDG_DATA_DIRS";
  };

  xdg.enable = true;
  xdg.mime.enable = true;
}
