{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix

    ../../modules/core/nix.nix
    ../../modules/core/locale.nix
    ../../modules/core/users.nix
    ../../modules/core/nix-ld.nix
    ../../modules/core/packages.nix

    ../../modules/boot/loader.nix
    ../../modules/boot/kernel.nix
    ../../modules/boot/windows-entry.nix

    ../../modules/hardware/nvidia-prime.nix
    ../../modules/hardware/audio.nix
    ../../modules/hardware/bluetooth.nix
    ../../modules/hardware/graphics.nix
    ../../modules/hardware/udev-rules.nix

    ../../modules/services/backup.nix
    ../../modules/services/databases.nix
    ../../modules/services/nginx.nix
    ../../modules/services/ollama.nix
    ../../modules/services/virtualisation.nix

    ../../modules/desktop/display-manager.nix
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/hyprland
    ../../modules/desktop/portals.nix
    ../../modules/desktop/polkit.nix
    ../../modules/desktop/keyring.nix

    ../../modules/emacs.nix
    ../../modules/launcher.nix
    ../../modules/observability.nix
  ];

  services.guix.enable = true;

  nixpkgs.config.allowUnfree = true;

  systemd.tmpfiles.rules = [
    "d ${config.users.users.tco.home}/.cache/wal 0755 tco users -"
    "d /home/nix-build 2775 root nixbld - -"
    "d /nix/var/nix/profiles/per-user/tco 0755 tco users -"
    "d /nix/var/nix/gcroots/per-user/tco 0755 tco users -"
  ];

  fileSystems."/build" = {
    device = "/home/nix-build";
    fsType = "none";
    options = [
      "bind"
      "x-systemd.requires-mounts-for=/home"
      "x-systemd.mkdir"
    ];
    neededForBoot = false;
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Démo Bernstein (seminar-dop) : résolution locale vers un nœud du cluster DOKS.
  # /!\ IP éphémère — à retirer/mettre à jour si le cluster est recréé.
  networking.extraHosts = ''
    157.230.26.170 poll.dop.io result.dop.io
  '';

  home-manager.backupFileExtension = "backup";

  services.logind.settings.Login.KillUserProcesses = true;
  systemd.settings.Manager.DefaultTimeoutStopSec = "15s";

  programs.zoxide.enable = true;
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  services.logrotate.enable = true;

  environment.systemPackages = with pkgs; [
    (python313.withPackages (ps: with ps; [
      pydantic
      anyio
      smbus2
      pyserial
    ]))

    i2c-tools

    adwaita-icon-theme
    papirus-icon-theme
    bibata-cursors
    brightnessctl
    appimage-run
    fuse2
    fuse3
    libxshmfence
    bash
    vim
    neovim
    git
    wget
    curl
    jq
    lsof
    iw
    ethtool
    pciutils
    usbutils
    tree
    ripgrep
    fd
    fzf
    fastfetch
    btop
    htop
    kitty
    foot
    firefox
    google-chrome
    wl-clipboard
    pavucontrol
    networkmanager
    polkit_gnome
    nix-ld
    mesa
    libglvnd
    libdrm
    steam-run
    wineWow64Packages.stable
    winetricks
    just
    eza
    openhantek6022
  ];

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

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  system.stateVersion = "26.05";
}
