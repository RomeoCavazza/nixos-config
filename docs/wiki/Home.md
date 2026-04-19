# NixOS Workstation: Sovereignty by Design

[![NixOS](https://img.shields.io/badge/NixOS-26.05%20Unstable-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-v0.54.2-blue)](https://hyprland.org)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-Integrated-4E9A06)](https://github.com/nix-community/home-manager)
[![SOPS-nix](https://img.shields.io/badge/Secrets-SOPS%2FAge-FF6600)](https://github.com/Mic92/sops-nix)
[![Observability](https://img.shields.io/badge/Observability-Prometheus%20%7C%20Loki%20%7C%20Grafana-0E7490?logo=grafana&logoColor=white)](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics)

> **Infrastructure as Code pushed to its limit, applied to the personal workstation.**  
> This is a fully declarative, reproducible, and auditable system built on the philosophy of digital sovereignty.

![](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/htop.png)

---

## Overview

The [**GitHub Wiki**](https://github.com/RomeoCavazza/setup-os/wiki) is the primary documentation resource for this repository.

- [Architecture & Flake Logic](https://github.com/RomeoCavazza/setup-os/wiki/Architecture-&-Flake-Logic) — inputs, overlays, build flow, and rollback strategy.
- [Modules Breakdown](https://github.com/RomeoCavazza/setup-os/wiki/Modules-Breakdown) — per-module deep-dive into the engineering decisions.
- [Security & Secrets](https://github.com/RomeoCavazza/setup-os/wiki/Security-&-Secrets) — SOPS/Age cryptographic model and secret lifecycle.
- [Observability and Metrics](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics) — Dashboards, correlation logs, and live snapshots.

---

## The Vision: A Desktop for Life

Managing a workstation with NixOS is a move from **mutable, opaque environments** to a **declarative state**. It represents the same discipline that production infrastructure demands: every change goes through code, every dependency is pinned, and every secret is encrypted.

The goal is to reclaim **Digital Sovereignty**. On this machine, nothing is "magic." If a tool isn't declared in the configuration, it doesn't exist. This eliminates configuration drift and ensures that the system you run today is the exact system you will run in five years, on any hardware.

### Core Properties

**Reproducibility.** The entire system state is pinned in `flake.lock`. A cold reinstall is a `git clone` followed by a single command. It eliminates the "works on my machine" problem—the `flake.lock` file is the contract.

**Security.** Secrets (API keys, backup credentials) are encrypted with **SOPS/Age**. They are decrypted into a `tmpfs` (RAM-only) at activation, leaving no trace on disk. The system identity itself handles decryption, ensuring that secrets never enter the repository in plaintext.

**Observability.** A production-grade SRE stack (Prometheus, Loki, Grafana) monitors the host. This builds the intuition needed to manage high-availability systems by watching a real machine under real workloads.

---

## Architecture & Logic

The configuration defines a single system output, `nixosConfigurations.nixos`, which applies two layers atomically:
1.  **NixOS System Layer**: Kernel, drivers, and system services defined in `configuration.nix`.
2.  **Home Manager Layer**: Editor, shell, and user-space tools defined in `home/tco/home.nix`.

Both layers are versioned in the same flake. It is not possible to apply a system update without syncing the user environment, and a failure in either part prevents activation of the entire rebuild.

---

## Desktop Environment

**GDM** serves as the display manager, allowing a seamless choice between **Hyprland** (on Wayland) and **GNOME** (as a fallback). The two environments coexist without friction, sharing the same audio (Pipewire) and portal layers.

The Hyprland setup is highly custom, using plugins for workspace overviews and infinite canvas layouts. Dynamic theming is handled via **PyWal**, which synchronizes the color palette of the terminal, status bar, and compositor based on the active wallpaper.

---

## Development Toolchains

Each engineering domain is encapsulated in a dedicated module. Enabling a full toolchain is a single import line away:
- **Rust & systems programming** (via `rust-overlay`).
- **Python & Data Engineering** (with InfluxDB, PostgreSQL, Qdrant).
- **Local AI & LLMs** (via Ollama on CUDA and vector search).
- **Embedded & Hardware** (Arduino, ESPTool, KiCad, FreeCAD).

---

## Quick Reference

```bash
# Full system rebuild — applies system and user configuration atomically
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Update all flake inputs and rebuild
nix flake update && sudo nixos-rebuild switch --flake .#nixos

# Preview changes before switching
sudo nixos-rebuild build --flake .#nixos && nvd diff /run/current-system result

# Edit an encrypted secret
sops secrets/backup.yaml
```

---

*This wiki is the living documentation of a system that defines its own existence. Fork it, improve it, and reclaim your digital sovereignty.*
