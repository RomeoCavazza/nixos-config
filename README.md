<div align="center">
  <img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/logo/nixos.png" alt="NixOS Logo" width="120">
  <h1>NixOS dotfiles</h1>

  <div align="center">
    <img src="https://img.shields.io/badge/NixOS-5277C3?style=flat-square&logo=nixos&logoColor=white" alt="NixOS">
    <img src="https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=white" alt="Hyprland">
    <img src="https://img.shields.io/badge/GNOME-4A86CF?style=flat-square&logo=gnome&logoColor=white" alt="GNOME">
    <img src="https://img.shields.io/badge/Nix%20Flakes-7EBAE4?style=flat-square&logo=snowflake&logoColor=white" alt="Nix Flakes">
    <img src="https://img.shields.io/badge/Guix-FFD700?style=flat-square&logo=gnu&logoColor=black" alt="Guix">
    <img src="https://img.shields.io/badge/NVIDIA%20Prime-76B900?style=flat-square&logo=nvidia&logoColor=white" alt="NVIDIA Prime">
    <img src="https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white" alt="Prometheus">
    <img src="https://img.shields.io/badge/Loki-0E7490?style=flat-square&logo=grafana&logoColor=white" alt="Loki">
    <img src="https://img.shields.io/badge/Grafana-F46800?style=flat-square&logo=grafana&logoColor=white" alt="Grafana">
    <a href="https://github.com/RomeoCavazza/nixos-config/actions/workflows/ci.yml"><img src="https://github.com/RomeoCavazza/nixos-config/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  </div>
</div>

A reproducible, single-host NixOS workstation: a Hyprland/GNOME desktop on a LUKS-encrypted disk behind Secure Boot with TPM2 unlock, SOPS-managed secrets, and an integrated Prometheus/Loki/Grafana stack. Assembled from a constellation of small, pinned repositories.

<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/architecture.png" alt="System architecture" width="100%">

---

## Documentation

The [**GitHub Wiki**](https://github.com/RomeoCavazza/nixos-config/wiki) is the primary reference:

- [Architecture](https://github.com/RomeoCavazza/nixos-config/wiki/Architecture) — how the flake, profiles, and modules assemble the machine.
- [Modules](https://github.com/RomeoCavazza/nixos-config/wiki/Modules) — what each system module does and why.
- [Security](https://github.com/RomeoCavazza/nixos-config/wiki/Security) — disk encryption, verified boot, secrets, and backups.
- [Observability](https://github.com/RomeoCavazza/nixos-config/wiki/Observability) — dashboards, correlation logs, and live snapshots.

```
.
├── flake.nix        # Inputs + the `legion` output
├── flake/           # mk-host, quality, profile selection
├── profiles/        # Composable feature bundles (system + home)
├── hosts/legion/    # Host config + hardware-configuration.nix
├── modules/         # System modules by domain
├── home/tco/        # Home Manager (packages/, hyprland/, ...)
├── lib/             # palette, colors, fonts, locality
├── pkgs/ overlays/  # Custom packages + nixpkgs overlays
├── config/          # Local scripts and Grafana sources
└── secrets/         # SOPS-encrypted secrets
```

---

## Constellation

This dotfile is not a monolith — it is composed from small, single-purpose repositories, each pinned as a flake input and documented on its own:

| Repository | Role |
|---|---|
| [`hyprland-config`](https://github.com/RomeoCavazza/hyprland-config) | Hyprland compositor, Waybar, Rofi, foot |
| [`conky-config`](https://github.com/RomeoCavazza/conky-config) | Transparent Conky telemetry rails |
| [`hypr-canvas`](https://github.com/RomeoCavazza/hypr-canvas) | Native infinite-canvas Hyprland plugin |
| [`hyprspace`](https://github.com/RomeoCavazza/hyprspace) | Workspace overview plugin |
| [`hyprchroma`](https://github.com/RomeoCavazza/hyprchroma) | Chromakey transparency plugin |
| [`nvim-config`](https://github.com/RomeoCavazza/nvim-config) | Neovim configuration |
| [`emacs-config`](https://github.com/RomeoCavazza/emacs-config) | Doom Emacs configuration |
| [`grafana-config`](https://github.com/RomeoCavazza/grafana-config) | Grafana dashboards (Jsonnet) |
| [`ventoy-config`](https://github.com/RomeoCavazza/ventoy-config) | Multiboot recovery USB |

---

## Desktop

> [!TIP]
> GDM offers both desktops at login — switch between **Hyprland** (Wayland) and **GNOME** without friction.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#161b22', 'secondaryColor': '#0d1117', 'tertiaryColor': '#0d1117', 'primaryBorderColor': '#94e2d5', 'lineColor': '#94e2d5', 'primaryTextColor': '#c9d1d9', 'mainBkg': '#0d1117', 'clusterBkg': '#161b22', 'clusterBorder': '#30363d' }}}%%
flowchart TB
  Boot["Boot"]
  GDM["GDM"]
  H["Hyprland"]
  G["GNOME"]

  Boot --> GDM
  GDM --> H
  GDM --> G
```

### GNOME
![GNOME Desktop](https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/gnome-desktop.webp)

<br>

### Hyprland
![Hyprland Desktop](https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/screen-fastfetch.webp)

<br>

### Neovim
<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/screen-nvim.webp" alt="Neovim Screen" width="100%">

<br>

### Virtualization
<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/virual-machine.webp" alt="Virtual Machine Screen" width="100%">

<br>

### Hardware and Modeling
<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/screen-cad.webp" alt="CAD Screen" width="100%">

<br>

### System Metrics
<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/htop.webp" alt="HTOP Screen" width="100%">

<br>

### NVIDIA Prime
<img src="https://raw.githubusercontent.com/wiki/RomeoCavazza/nixos-config/images/nixos-config/docs/assets/screen-nvidia.webp" alt="NVIDIA Screen" width="100%">

---

## Live Infrastructure

![Live NixOS Metrics](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/snapshots/docs/assets/live/live-dashboard.png)

Prometheus, Loki, Grafana, and Promtail provide local observability. The snapshots committed on the `snapshots` branch are documentation artifacts only, refreshed by a systemd timer when the visual delta exceeds 0.3%. Live operations stay in Grafana.

- [NixOS Metrics](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/snapshots/docs/assets/live/live-dashboard.png) — current pressure and rebuild cost
- [Nix Efficiency](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/snapshots/docs/assets/live/nix-efficiency.png) — freshness, generation debt, closure structure
- [Incident Correlation](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/snapshots/docs/assets/live/incident-dashboard.png) — pressure spikes mapped to Loki logs

Details on the [Observability](https://github.com/RomeoCavazza/nixos-config/wiki/Observability) wiki page.

---

## Security and Backups

The disk is LUKS-encrypted and unlocked by a TPM2 keyslot behind Secure Boot ([Lanzaboote](https://github.com/nix-community/lanzaboote)); the layout is declarative via [disko](https://github.com/nix-community/disko). Secrets are committed only in encrypted form under [`secrets/`](./secrets/) with [sops-nix](https://github.com/Mic92/sops-nix). Backups use `restic` to Backblaze B2, split into `b2-critical` and `b2-data`, with a weekly non-destructive restore drill. Full model on the [Security](https://github.com/RomeoCavazza/nixos-config/wiki/Security) wiki page.

---

## Installation

> [!IMPORTANT]
> This configuration targets a specific host — review hardware IDs, filesystems, secrets, and service assumptions before reusing it. Features are enabled by composing profiles in [`profiles/`](./profiles/), which the host assembles in [`hosts/legion/profiles.nix`](./hosts/legion/profiles.nix).

Prerequisites: a [NixOS ISO](https://channels.nixos.org/nixos-unstable/latest-nixos-graphical-x86_64-linux.iso) on a bootable USB ([Ventoy](https://www.ventoy.net/en/download.html) or [Rufus](https://rufus.ie/en/)).

```bash
# 1. Back up the current config
sudo cp -r /etc/nixos /etc/nixos-backup

# 2. Clone
git clone https://github.com/RomeoCavazza/nixos-config.git ~/dev/nixos-config

# 3. Apply
cd ~/dev/nixos-config && sudo nixos-rebuild switch --flake .#legion
```
