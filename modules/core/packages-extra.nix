{ pkgs, ... }:

{
  # Catch-all system package set, moved verbatim from the host (no functional sorting).
  # TODO: split into core CLI / desktop / dev / gaming / media / hardware in a later run.
  environment.systemPackages = with pkgs; [
    (python313.withPackages (
      ps: with ps; [
        pydantic
        anyio
        smbus2
        pyserial
      ]
    ))

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
}
