<div align="center">
  <img src="./assets/nixos.png" alt="NixOS Logo" width="120">
  <h1>NixOS dotfiles</h1>
  <p><strong>Declarative, modular, and optimized workstation configuration</strong></p>

  <div align="center">
    <img src="https://img.shields.io/badge/NixOS-26.05_(Yarara)-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS">
    <img src="https://img.shields.io/badge/Hyprland-Desktop-58E1FF?style=for-the-badge&logo=hyprland&logoColor=white" alt="Hyprland">
    <img src="https://img.shields.io/badge/GNOME-Desktop-4A86CF?style=for-the-badge&logo=gnome&logoColor=white" alt="GNOME">
    <img src="https://img.shields.io/badge/Flakes-Enabled-7EBAE4?style=for-the-badge&logo=snowflake&logoColor=white" alt="Flakes">
    <img src="https://img.shields.io/badge/Guix-Enabled-FFD700?style=for-the-badge&logo=gnu-guix&logoColor=white" alt="Guix">
    <img src="https://img.shields.io/badge/NVIDIA-Prime-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="NVIDIA">
  </div>
</div>

---

## • Overview •

> [!IMPORTANT]
> **Warning**: This configuration is tailored for my hardware. Don't blindly use these settings unless you know what they entail. Use at your own risk!

> [!NOTE]
> This repository uses a modular structure, allowing you to easily toggle specific services (databases, AI, monitoring) by importing the corresponding files in `configuration.nix`.

```
nixos/
├── config/
│   ├── bin/          # Custom scripts
│   ├── doom/         # Doom Emacs
│   ├── foot/         # Terminal
│   └── hypr/         # Hyprland + Waybar
├── home/tco/         # Home Manager
├── modules/          # Toggleable system modules
│   ├── databases.nix
│   ├── nvidia-prime.nix
│   ├── ollama.nix
│   ├── observability.nix
│   └── ...
├── configuration.nix
├── flake.nix
└── flake.lock
```

---

## • Screenshots •

<div align="center">
  <img src="./assets/hero-video.gif" alt="Desktop demo" width="100%">
</div>

<br>

<div align="center">
  <img src="./assets/screen-waybar.png" alt="Waybar showcase" width="100%">
  <p><em>Desktop Interface — <a href="./config/hypr/waybar">Waybar Configuration</a></em></p>
</div>

<br>

> [!TIP]
> This setup ships with **two desktop environments** accessible via GDM — switch seamlessly between **Hyprland** and **GNOME** at login.

<div align="center">
  <h4>GNOME</h4>
  <img src="./assets/gnome-desktop.png" alt="GNOME Desktop" width="100%">
</div>

<br>

<div align="center">
  <h4>Hyprland</h4>
  <img src="./assets/screen-fastfetch.png" alt="Hyprland Desktop" width="100%">
</div>

<br>

| Hardware & Modeling | Code Environment |
|:---:|:---:|
| <img src="./assets/screen-cad.png" alt="CAD Screen" width="100%"> | <img src="./assets/screen-nvim.png" alt="Neovim Screen" width="100%"> |
| **System Metrics** | **Graphics Engine** |
| <img src="./assets/screen-htop.png" alt="HTOP Screen" width="100%"> | <img src="./assets/screen-nvidia.png" alt="NVIDIA Screen" width="100%"> |

---

## • Installation •

### Prerequisites
- [NixOS ISO](https://channels.nixos.org/nixos-unstable/latest-nixos-graphical-x86_64-linux.iso)
- [Ventoy](https://www.ventoy.net/en/download.html) or [Rufus](https://rufus.ie/en/) to create a bootable USB drive.

### Setup Instructions

> [!TIP]
> You can test individual development environments without installing them globally by using `nix develop .#ai` or `nix develop .#embedded`.

1. **Backup your current config**:
   ```bash
   sudo cp -r /etc/nixos /etc/nixos-backup
   ```

2. **Clone this repository**:
   ```bash
   sudo git clone https://github.com/RomeoCavazza/setup-os.git /etc/nixos-new
   sudo cp -r /etc/nixos-new/* /etc/nixos/
   ```

3. **Apply the configuration**:
   ```bash
   cd /etc/nixos
   sudo nixos-rebuild switch --flake .#nixos
   ```

