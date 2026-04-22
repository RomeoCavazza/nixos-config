{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/nvidia-prime.nix
    ./modules/virtualisation.nix
    ./modules/emacs.nix
    ./modules/launcher.nix
    ./modules/databases.nix
    ./modules/ollama.nix
    ./modules/nginx.nix
    ./modules/observability.nix
    ./modules/gdm-wallpaper.nix
  ];

  services.guix.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;
  boot.loader.systemd-boot.configurationLimit = 1;
  boot.loader.timeout = null;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.systemd-boot.extraEntries."windows.conf" = ''
    title Windows 11
    sort-key windows
    efi /EFI/Microsoft/Boot/bootmgfw.efi
  '';

  # Force systemd-boot menu to always show and wait indefinitely (menu-force).
  # NixOS doesn't support "menu-force" natively (timeout only accepts null|int),
  # so we patch loader.conf after the installer writes it.
  boot.loader.systemd-boot.extraInstallCommands = ''
    conf=/boot/loader/loader.conf
    ${pkgs.gnused}/bin/sed -i '/^timeout /d; /^auto-entries /d' "$conf"
    echo "timeout menu-force" >> "$conf"
    echo "auto-entries no" >> "$conf"
  '';

  boot.kernelModules = [ "i2c-dev" "i2c-i801" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "pcie_aspm=off"
  ];

  boot.blacklistedKernelModules = [
    "iTCO_wdt"
    "iTCO_vendor_support"
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    allowed-users = [ "@wheel" "tco" ];
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    warn-dirty = false;
    download-buffer-size = 268435456;
    sandbox = true;
    sandbox-build-dir = "/build";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

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

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    curl
    glib
    gtk3
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    gdk-pixbuf
    dbus
    expat
    udev
    alsa-lib
    cups
    nspr
    nss
    libxshmfence
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libxkbfile
    libxkbcommon
    mesa
    libgbm
    libglvnd
    libdrm
  ];

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  users.users.tco = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [ "wheel" "networkmanager" "video" "docker" "libvirtd" "dialout" "i2c" ];
  };

  services.xserver = {
    enable = true;
    xkb.layout = "fr";
  };

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.customWallpaper = {
    enable = true;
    path = ./docs/assets/gdm-background.png;
  };
  services.desktopManager.gnome.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  home-manager.backupFileExtension = "backup";

  hardware.enableRedistributableFirmware = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.hardware.openrgb.enable = true;

  security.polkit.enable = true;

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

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
    ]))
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
    sigrok-cli
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    EDITOR = "vim";
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Local USB device access rule.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04b5", ATTRS{idProduct}=="6cde", MODE="0666"
  '';

  system.stateVersion = "26.05";
}
