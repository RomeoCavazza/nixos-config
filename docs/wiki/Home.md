# NixOS Workstation Configuration

[![NixOS](https://img.shields.io/badge/NixOS-26.05%20Unstable-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-v0.54.2-blue)](https://hyprland.org)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-Integrated-4E9A06)](https://github.com/nix-community/home-manager)
[![SOPS-nix](https://img.shields.io/badge/Secrets-SOPS%2FAge-FF6600)](https://github.com/Mic92/sops-nix)
[![Observability](https://img.shields.io/badge/Observability-Prometheus%20%7C%20Loki%20%7C%20Grafana-0E7490?logo=grafana&logoColor=white)](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics)
[![Live Snapshots](https://img.shields.io/badge/Live%20Snapshots-Auto--Published-22c55e?logo=github&logoColor=white)](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/live/nix-efficiency.png)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)

> **Declarative, reproducible, and auditable infrastructure for a development workstation.**  
> Managed entirely through Nix Flakes, Home Manager, and encrypted secrets — rebuilt from scratch in a single command.

![](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/htop.png)

## Wiki Pages

- [Architecture & Flake Logic](https://github.com/RomeoCavazza/setup-os/wiki/Architecture-&-Flake-Logic) — inputs, overlays, build flow, rollback strategy, store hygiene
- [Security & Secrets](https://github.com/RomeoCavazza/setup-os/wiki/Security-&-Secrets) — SOPS/Age cryptographic model, secret lifecycle, backup encryption
- [Modules Breakdown](https://github.com/RomeoCavazza/setup-os/wiki/Modules-Breakdown) — per-module deep-dive with the reasoning behind each configuration decision
- [Observability and Metrics](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics) — PSI gauges, Nix efficiency dashboards, Loki correlation, and live snapshot publication

---

## What This Is

This repository is not a collection of dotfiles. It is a fully declarative system configuration covering the entire stack — kernel parameters, GPU drivers, system services, user packages, editor configuration, application themes, and encrypted cloud backups — expressed as version-controlled Nix code.

The machine is a Lenovo Legion laptop running NixOS on an Intel/NVIDIA hybrid setup. The primary compositor is Hyprland on Wayland, with GNOME available as a secondary session through GDM. Both environments coexist without conflicts: GDM handles session selection at login, and each session manages its own portal and audio backends independently. The system channel tracks `nixos-unstable` for access to current drivers and toolchains, while a subset of packages is pinned to `nixos-24.11` where stability or compatibility requires it. The entire state of the machine — what runs, what is installed, how services are configured — is defined by this repository. Nothing runs on this machine that is not declared here.

---

## Why This Matters

Managing a personal workstation with Nix Flakes is a deliberate engineering choice, not an aesthetic one. It imposes the same discipline that production infrastructure demands: every change goes through code, every dependency is pinned, every secret is treated as sensitive material. The result is a system that behaves identically after a full reinstall, on a different disk, or months later — because its state is entirely defined by the repository, not by accumulated manual steps.

Three properties define a production-grade infrastructure. This configuration demonstrates all three at the workstation level.

**Reproducibility.** The entire system state is pinned in `flake.lock`. A cold reinstall is a `git clone` followed by a single `nixos-rebuild switch`. No manual steps, no configuration drift, no "works on my machine." The `flake.lock` file is the contract: what is pinned there is what runs. Updates are explicit, reviewed via `git diff flake.lock`, and applied atomically on the next rebuild.

**Security.** API keys and backup credentials are encrypted with Age before being committed to the repository. They are decrypted into an ephemeral `tmpfs` mount at activation time by the machine's own Age identity, which never enters the repository. The key property of SOPS is that it encrypts values while leaving keys in plaintext — so the structure of what secrets exist is auditable without exposing the content. Decrypted material lives only in RAM and is gone on reboot.

**Observability.** A complete local monitoring stack runs as NixOS services. Prometheus scrapes system metrics from Node Exporter, Promtail ships the systemd journal to Loki, and Grafana provides unified dashboards pre-wired to both sources. The rationale is practical: understanding what a healthy system looks like at the metrics level — CPU patterns, memory pressure, driver events, service restart frequency — is intuition built by watching a real system, not by reading documentation. Running the same tools used in production on a personal machine builds that intuition daily.

---

## Repository Structure

The repository is organized around a clear separation of concerns. `flake.nix` declares what the system depends on. `configuration.nix` declares what services the system runs. `home/tco/home.nix` declares what the user environment looks like. The `modules/` directory contains the implementation of each service, kept separate so any module can be toggled, audited, or copied to another host independently.

The `config/` directory holds application dotfiles — Hyprland, Waybar, Rofi, the foot terminal, Doom Emacs, and others — which Home Manager symlinks into place during activation. The `secrets/` directory holds SOPS-encrypted credential files. The `docs/` directory holds architecture documentation and technical specifications.

---

## Architecture

The flake defines a single system output, `nixosConfigurations.nixos`, which combines two independent trees applied atomically on every rebuild. The first is the NixOS system layer — kernel, drivers, services, system packages — built from `configuration.nix` and the modules it imports. The second is the Home Manager user layer — editor configuration, shell, themes, user-space applications — built from `home/tco/home.nix`. Home Manager is embedded inline in the flake rather than managed as a separate command, which means both layers are always in sync. It is not possible to apply a system change without also applying the corresponding user change, and if either half fails to build, neither is activated.

The flake declares ten external inputs. The base system tracks `nixos-unstable` for current packages. Two packages — `promtail` and `guix` — are sourced from `nixos-24.11` via a custom overlay to avoid module conflicts and build environment issues that exist on the unstable channel. Hyprland and all three of its plugins are pinned to the same exact version tag, because compositor plugins share internal ABI with the compositor binary and a version mismatch between the two causes crashes or silent failures at load time. The plugin sources are vendored locally in `home/tco/pkgs/` and compiled during `nixos-rebuild` against the pinned Hyprland headers — no binary downloads, no version ambiguity.

Three overlays are applied to the package set before any module evaluates: one from `rust-overlay` to inject Rust toolchains, one from the Hyprland flake to inject compositor packages, and one custom overlay that pulls `promtail` and `guix` from the stable channel.

---

## Desktop Environment

GDM is the display manager. At login, the user selects between Hyprland as the primary Wayland compositor and GNOME as a full fallback session. The two environments share the same audio backend (Pipewire), the same portal layer, and the same user packages, with no conflicts between them.

The Hyprland setup goes beyond basic window manager configuration. Three plugins are compiled from RomeoCavazza GitHub forks: Hyprspace provides a workspace overview, hypr-canvas provides an infinite canvas for grouping workspaces, and Hyprchroma applies an adaptive tint shader. Color theming is handled dynamically by PyWal, which extracts a palette from the active wallpaper and writes it into template files that Hyprland, the foot terminal, and Waybar all read — keeping the color scheme consistent across every visible surface without manual coordination.

---

## Development Tooling

The workstation is configured for multiple engineering disciplines. Rather than installing tools ad hoc, each domain has a dedicated module — either a Home Manager module for user-space tools or a NixOS module for services — so the full toolchain for any domain is available immediately after a rebuild and equally cleanly removed by dropping an import.

The domains covered include Rust systems programming, Python data work, web development, CAD and PCB design with KiCad and FreeCAD, embedded firmware work with Arduino and esptool, database engineering with PostgreSQL and Qdrant, and local LLM inference through Ollama on CUDA. The breadth reflects a generalist engineering practice where the workstation adapts to the problem at hand.

---

## Quick Reference

```bash
# Full system rebuild — applies system and user configuration atomically
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Update all flake inputs and rebuild
nix flake update && sudo nixos-rebuild switch --flake .#nixos

# Preview what will change before switching
sudo nixos-rebuild build --flake .#nixos && nvd diff /run/current-system result

# Edit an encrypted secret
sops secrets/backup.yaml

# Check backup timer schedule
systemctl list-timers | grep restic

# Check observability stack status
systemctl status prometheus grafana loki
```

---

*This wiki is generated from source — the configuration it describes is the configuration that runs.*
