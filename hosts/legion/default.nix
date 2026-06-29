{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/workstation.nix
  ];

  services.guix.enable = true;

  nixpkgs.config.allowUnfree = true;

  systemd.tmpfiles.rules = [
    "d ${config.users.users.tco.home}/.cache/wal 0755 tco users -"
    "d /nix/var/nix/profiles/per-user/tco 0755 tco users -"
    "d /nix/var/nix/gcroots/per-user/tco 0755 tco users -"
  ];

  home-manager.backupFileExtension = "backup";

  environment.shellAliases = {
    scope = "bash ~/Applications/launch-hantek.sh";
    tinysa = "bash ~/Applications/launch-tinysa.sh";
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    EDITOR = "vim";

    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
  };

  system.stateVersion = "26.05";
}
