# Technical Deep Dive

Technical documentation annexes for the `setup-os` NixOS configuration — covering every layer of the system in dependency order.

---

## 1. Nix Flake Structure

The entire system is defined by a single `flake.nix`. It acts as the entry point for everything: system builds, user environments, and overlay composition.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/diagrams/flake-outputs.png)

The flake pins ten inputs. `nixpkgs` (unstable) is the primary package set. `nixpkgs-stable` is used for two specific packages — Guix, which requires a stable release, and Promtail, which has a module-level conflict with the current Loki version on unstable. `rust-overlay` injects Rust nightly and stable toolchains via an overlay. Hyprland is pinned to `v0.54.2`, and all three plugins (`hyprspace`, `hyprland-plugins`, `hyprtasking`) follow that exact version via `inputs.hyprland.follows` — this prevents ABI mismatches between the compositor and its plugins.

The sole output is `nixosConfigurations.nixos`. Home Manager is embedded inline, so `sudo nixos-rebuild switch` applies system configuration, secret wiring, backup units, and user environment atomically in a single transaction.

---

## 2. System Layer — `configuration.nix` and Modules

`configuration.nix` is the NixOS entry point. It stays readable because all optional system behaviors are extracted into discrete modules under `modules/` and explicitly listed in `imports`. Adding or removing a module is a single line change with no side effects on the rest of the file.

**Active system modules:**

| Module | Purpose |
|--------|---------|
| `nvidia-prime.nix` | NVIDIA PRIME offload — Intel iGPU primary, NVIDIA on-demand |
| `virtualisation.nix` | Docker, libvirt/KVM, QEMU, ARM binfmt emulation |
| `emacs.nix` | Emacs daemon (pgtk, Wayland-native) + LSP tools + LaTeX |
| `launcher.nix` | gvfs, udisks2, Rofi, Waybar, Nemo |
| `databases.nix` | PostgreSQL 17 + PostGIS, Redis, Qdrant |
| `ollama.nix` | Ollama CUDA daemon — 32K context, 24h keep-alive |
| `nginx.nix` | Localhost reverse proxy (ports 8081–8083) |
| `observability.nix` | Prometheus, Loki, Promtail, Grafana |
| `backup.nix` | Restic encrypted snapshots to Backblaze B2 via sops-nix |
| `gdm-wallpaper.nix` | Custom NixOS module — patches gnome-shell-theme.gresource |

The boot configuration uses `systemd-boot` with `configurationLimit = 1`, which keeps exactly one NixOS entry in the boot menu. This limits disk usage from accumulated boot entries; rollback is done via `sudo nixos-rebuild switch --rollback` from a running session rather than the boot menu. A custom `windows.conf` entry is injected into the EFI loader for Windows 11 dual-boot.

The Nix runtime is configured with `auto-optimise-store = true` (hard-link deduplication across the store), a weekly GC that removes generations older than 7 days, and a custom build directory at `/build` — a bind mount of `/home/nix-build` — to keep large build artifacts off the root partition during sandbox evaluation.

**NVIDIA PRIME** (`nvidia-prime.nix`): Intel iGPU handles display output at all times. The NVIDIA GPU is powered off by default and wakes on demand when a process uses the `nvidia-offload` wrapper. `powerManagement.finegrained = true` enables full D3cold power-gating, bringing idle GPU draw from ~15W down to ~0.5W. Bus IDs: Intel at `PCI:0:2:0`, NVIDIA at `PCI:2:0:0`.

**Virtualisation** (`virtualisation.nix`): Docker runs with weekly autoPrune. `virt-manager` and `quickemu` cover KVM/QEMU needs. `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` registers ARM64 ELF binaries with QEMU user-mode as the interpreter, enabling transparent ARM binary execution and direct Raspberry Pi image builds on x86_64.

---

## 3. Display, Audio & Connectivity

GDM manages session selection at login, offering both a Hyprland (Wayland) session and a GNOME session. The two environments coexist cleanly: XDG portals are configured for both backends (`xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk`), ensuring screen sharing, file pickers, and portal-dependent applications work correctly in whichever session is active.

Audio runs through Pipewire with the full compatibility layer enabled: ALSA with 32-bit support for Steam and legacy applications, and the PulseAudio compatibility API for tools that predate native Pipewire support. `cava` hooks into Pipewire and is used both as a standalone visualizer and as the data source for the Waybar audio visualization module.

`programs.nix-ld` provides a compatibility shim for non-Nix ELF binaries — AppImages, pre-built proprietary tools, vendor SDKs — by injecting a curated set of libraries (`glib`, `gtk3`, `mesa`, `libx11`, `libdrm`, `nss`, and others) into the dynamic linker search path. This is what allows tools like the Cursor editor AppImage to run without manual `patchelf` invocations.

**Encrypted backups** are built directly into the flake via `modules/backup.nix`. `sops-nix` decrypts Backblaze and Restic credentials at activation time into an ephemeral `/run/secrets/` tmpfs. `restic` writes AES-256 encrypted snapshots to a Backblaze B2 bucket over the S3-compatible endpoint. Two independent jobs run nightly: `b2-critical` backs up `/etc/nixos`, `~/.ssh`, `~/.gnupg`, and `~/.config`; `b2-data` backs up `~/Desktop`, `~/Documents`, and `~/Images`. Separating them allows independent retention policies and prevents a large user data backup from blocking the critical config backup.

---

## 4. User Layer — `home/tco/home.nix`

Home Manager runs inline within the system build, applied atomically on every `nixos-rebuild switch`. The user configuration covers package installation, dotfile symlinking, shell environment, program configuration, and GTK theming — all expressed as declarative Nix code in `home/tco/home.nix` and its imported modules.

**Dotfile strategy.** Application configs live under `config/` in the repository and are symlinked into place by Home Manager via `home.file` entries. Editing files directly at `/etc/nixos/config/hypr/hyprland.conf` takes effect immediately for Hyprland (which reads from the symlink target), and the change is tracked in git. The active symlink map:

```
~/.config/hypr     → /etc/nixos/config/hypr/
~/.config/waybar   → /etc/nixos/config/hypr/waybar/
~/.config/rofi     → /etc/nixos/config/rofi/
~/.config/foot     → /etc/nixos/config/foot/
~/.local/bin/      → scripts from /etc/nixos/config/bin/
```

**Session environment.** Qt applications are forced to Wayland (`QT_QPA_PLATFORM=wayland`) with Kvantum as the style engine. Electron apps use an X11 hint for stability. `~/.lmstudio/bin`, `~/.npm-global/bin`, and `~/.local/bin` are prepended to `$PATH`.

**User packages** cover shell utilities (bat, eza, fzf, yazi, zoxide), editors (Zed, Neovim, VSCode with Nix/Python/Rust extensions), AI coding tools (aider-chat, Cursor AppImage via wrapper), Rust and Node.js 22 toolchains, creative tools (OBS, Discord, Spotify), and system monitoring (btop, nvitop, glances). Domain-specific toolchains are grouped in optional app modules: `cad.nix` (Obsidian, KiCad, FreeCAD), `embedded.nix` (Arduino IDE/CLI, esptool, minicom), `data.nix` (DBeaver, Grafana, InfluxDB2).

**Hyprchroma / hypr-darkwindow.** The local Hyprchroma fork is compiled inline from `home/tco/pkgs/Hyprchroma-fork/src/main.cpp` during Home Manager activation, producing `~/.local/lib/libhypr-darkwindow.so`. The plugin provides inactive-window tinting and workspace-transition smoothing. Configuration lives in `config/hypr/theme/hyprchroma.conf`; the dispatcher `togglechromakey` enables runtime toggling.

**Pywal** is available in the user environment with custom templates tracked at `config/wal/templates/` and deployed to `~/.config/wal/templates/`. `colors-hyprland.conf` and `colors-foot.ini` allow wallpaper-derived palette generation when desired. The live desktop theme is repo-defined by default; pywal is opt-in per session.

**Shell:** Bash with Starship prompt (Catppuccin-style teal gradient). Key alias: `rebuild` → `command rebuild` (wrapper script with rebuild metrics export).

---

## 5. Desktop Environment — Hyprland + Seaglass Theme

Hyprland is a tiling Wayland compositor with XWayland enabled for X11 application compatibility. Its configuration lives in `config/hypr/`. Three plugins extend the compositor: Hyprspace (workspace overview, Exposé-style), hypr-canvas (infinite canvas for workspace grouping), and Hyprchroma/hypr-darkwindow (adaptive tint shader). All three are compiled from RomeoCavazza GitHub forks pinned through Nix inputs or `fetchFromGitHub` for Hyprland v0.54.2.

The Seaglass visual theme uses teal (`#94E2D5`) as its accent and is propagated at the config layer — not injected at runtime — so the identity stays consistent across every component without coordination logic.

![Theme propagation](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/diagrams/theme-flow.png)

`seaglass.conf` sets border colors, 12px rounding, blur parameters, and active/inactive window states. Waybar uses tracked `mocha.css` for the full Catppuccin Mocha palette as CSS variables, while Nix compiles `style.scss` into the generated `style.css` that overrides the accent to `#94e2d5`. Modules have transparent backgrounds with `border-radius: 999px` and a subtle teal hover glow. Rofi uses `column-tco.rasi` for the sidebar layout and `apps-grid.rasi` for the application grid. The foot terminal palette is tracked directly in `config/foot/foot.ini`. GTK theme is Adwaita-dark with Papirus-Dark icons and Bibata-Modern-Ice cursor at size 24.

---

## 6. Waybar

Waybar is the Wayland status bar, configured from `config/hypr/waybar/` and materialized by Home Manager at `~/.config/waybar/`. The layout is defined in `config.jsonc`, the palette in tracked `mocha.css`, and per-component styles in generated `style.css` compiled from `style.scss`.

Two runtime scripts drive the dynamic modules. `WaybarCava.sh` generates a temporary Cava config on launch with 14 bars at 60fps over PulseAudio, pipes the raw ASCII output through character substitution and silence masking, and outputs unicode bar characters for the `custom/cava` module. `activeapp.sh` queries `hyprctl activewindow` for the focused window's class, maps it to a Nerd Font icon via a case statement (`firefox` → , `code` → 󰨞, `foot` → ), and outputs JSON for the active window module.

---

## 7. Rofi

Rofi is configured in `config/rofi/` with two active launch paths. The sidebar launcher runs via `rofi-push.sh`, which shifts Hyprland's `gaps_out` to create space for the panel without overlapping windows, then restores original gaps on close. The application grid runs via `rofi-grid.sh`, which temporarily increases blur size and kills Waybar on open, restoring both on exit. The sidebar uses `column-tco.rasi` and the grid uses `apps-grid.rasi`. Both are referenced from `hyprland.conf` via the `$menu` and `$powermenu` variables.

---

## 8. Development Tooling

Development environments are no longer exposed as flake `devShells`. The embedded and AI toolchains are installed directly through Home Manager and the user app modules, making them available in every shell without an explicit `nix develop` invocation. Per-project environments use project-local `flake.nix` files with `direnv` integration (`programs.direnv.enable = true` with `nix-direnv`).

The `rust-overlay` flake input remains active and injects Rust nightly and stable toolchains into `nixpkgs`, available both system-wide and in `home.nix`.

---

## 9. Code Metrics

Generated with `cloc`, excluding `.git`, `docs/assets`, and `docs/wiki`. Full report: [`cloc-report.md`](./cloc-report.md).

| Language | Files | Code |
|---|---:|---:|
| C++ | 8 | 2563 |
| Nix | 22 | 1629 |
| Markdown | 9 | 694 |
| JSON | 7 | 681 |
| Bourne Shell | 21 | 647 |
| Text | 3 | 475 |
| PlantUML | 9 | 360 |
| Bourne Again Shell | 14 | 357 |
| C/C++ Header | 3 | 150 |
| CSS | 2 | 125 |
| YAML | 5 | 106 |
| **Total** | **114** | **8 023** |

The C++ lines are the three locally vendored Hyprland plugins (`Hyprchroma-fork`, `hyprspace-fork`, `hypr-canvas-fork`), compiled from source during `nixos-rebuild`. The 22 Nix files cover the flake, system configuration, 10 system modules, and 3 Home Manager app modules. Shell scripts now split across Bourne Shell and Bourne Again Shell as more runtime automation was added for observability and snapshot publishing.
