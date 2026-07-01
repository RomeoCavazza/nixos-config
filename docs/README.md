# Technical Deep Dive

Technical documentation annexes for the `nixos-config` NixOS configuration — covering every layer of the system in dependency order.

---

## 1. Nix Flake Structure

The entire system is defined by a single [`flake.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.nix). It acts as the entry point for everything: system builds, user environments, and overlay composition.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/flake-outputs.png)

The flake tracks `nixpkgs` at `nixos-26.05` as the primary package set. `nixpkgs-legacy` (`nixos-24.11`) is pulled for a single package — `promtail`, which was removed from newer nixpkgs during the Loki 3 transition and is kept via an overlay in [`overlays/`](https://github.com/RomeoCavazza/nixos-config/blob/main/overlays/default.nix) until the host migrates to Grafana Alloy. `rust-overlay` injects Rust toolchains. Hyprland is pinned to `v0.55.4`, and the plugins that are flake inputs (`hyprspace`, `hyprland-plugins`, `hyprtasking`) follow that exact version via `inputs.hyprland.follows` — this prevents ABI mismatches between the compositor and its plugins. The remaining plugins (`hypr-canvas`, `hyprchroma`) are `flake = false` sources built as derivations under [`pkgs/hyprland-plugins/`](https://github.com/RomeoCavazza/nixos-config/blob/main/pkgs/hyprland-plugins/). `hypr-config` vendors the [`hyprland-config`](https://github.com/RomeoCavazza/hyprland-config) repository as the source for the Hyprland, Waybar, Rofi, and foot configurations. `nix-snapd` enables Snap package support; `sops-nix` handles secret decryption.

The primary output is `nixosConfigurations.legion`. The flake also exposes a `devShell` and `apps`/`checks` for the local quality gate — `nixfmt`, `deadnix`, `statix`, and a Grafana dashboard drift check. Home Manager is embedded inline, so a single rebuild applies system configuration, secret wiring, backup units, and the user environment atomically in one transaction. Builds go through the [`rebuild`](https://github.com/RomeoCavazza/nixos-config/blob/main/config/bin/rebuild) wrapper, which records build metrics and passes `--impure` so `locality.repoCheckout` resolves against the live checkout.

---

## 2. System Layer — Host, Profiles, and Modules

[`hosts/legion/default.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix) is the host entry point: it imports `hardware-configuration.nix` and [`profiles/workstation.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/profiles/workstation.nix), which composes the feature profiles (`core`, `boot`, `hardware`, `services`, `desktop-hyprland`, `launcher`, `observability`). Each profile imports the discrete modules it needs from [`modules/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/), grouped by domain — `boot/`, `core/`, `desktop/`, `hardware/`, `services/`, `observability/`. Enabling or disabling a capability is a single-line change in a profile, with no side effects elsewhere.

**Active system modules:**

| Module | Purpose |
|--------|---------|
| [`hardware/nvidia-prime.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/hardware/nvidia-prime.nix) | NVIDIA PRIME offload — Intel iGPU primary, NVIDIA on-demand |
| [`services/virtualisation.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/virtualisation.nix) | Docker, libvirt/KVM, QEMU, ARM binfmt emulation |
| [`desktop/launcher/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/desktop/launcher) | gvfs, udisks2, Rofi, Waybar, Nemo |
| [`services/databases.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/databases.nix) | PostgreSQL + PostGIS, Redis, Qdrant |
| [`services/ollama.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/ollama.nix) | Ollama CUDA daemon |
| [`services/nginx.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/nginx.nix) | Localhost reverse proxy |
| [`observability/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/observability) | Prometheus, Loki, Promtail, Grafana |
| [`services/backup.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/backup.nix) | Restic encrypted snapshots to Backblaze B2 via sops-nix |
| [`desktop/gdm-wallpaper.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/desktop/gdm-wallpaper.nix) | Custom module — patches gnome-shell-theme.gresource |

The Emacs daemon (pgtk, Wayland-native) is configured on the Home Manager side in [`home/tco/emacs.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/emacs.nix).

The boot configuration uses `systemd-boot`; rollback is done via `sudo nixos-rebuild switch --rollback` from a running session. A custom Windows entry is injected into the EFI loader for dual-boot ([`boot/windows-entry.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/boot/windows-entry.nix)).

**NVIDIA PRIME** ([`hardware/nvidia-prime.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/hardware/nvidia-prime.nix)): Intel iGPU handles display output at all times. The NVIDIA GPU is powered off by default and wakes on demand when a process uses the `nvidia-offload` wrapper. `powerManagement.finegrained = true` enables full D3cold power-gating, bringing idle GPU draw from ~15W down to ~0.5W. The Legion-specific bus IDs are set in the host file: Intel at `PCI:0:2:0`, NVIDIA at `PCI:2:0:0`.

**Virtualisation** ([`services/virtualisation.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/virtualisation.nix)): Docker runs with weekly autoPrune. `virt-manager` and `quickemu` cover KVM/QEMU needs. `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` registers ARM64 ELF binaries with QEMU user-mode as the interpreter, enabling transparent ARM binary execution and direct Raspberry Pi image builds on x86_64.

---

## 3. Display, Audio & Connectivity

GDM manages session selection at login, offering both a Hyprland (Wayland) session and a GNOME session. The two environments coexist cleanly: XDG portals are configured for both backends (`xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk`), ensuring screen sharing, file pickers, and portal-dependent applications work correctly in whichever session is active.

Audio runs through Pipewire with the full compatibility layer enabled: ALSA with 32-bit support for Steam and legacy applications, and the PulseAudio compatibility API for tools that predate native Pipewire support. `cava` hooks into Pipewire and is used both as a standalone visualizer and as the data source for the Waybar audio visualization module.

`programs.nix-ld` provides a compatibility shim for non-Nix ELF binaries — AppImages, pre-built proprietary tools, vendor SDKs — by injecting a curated set of libraries (`glib`, `gtk3`, `mesa`, `libx11`, `libdrm`, `nss`, and others) into the dynamic linker search path. This is what allows tools like the Cursor editor AppImage to run without manual `patchelf` invocations.

**Encrypted backups** are built directly into the flake via [`modules/services/backup.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/backup.nix). `sops-nix` decrypts Backblaze and Restic credentials at activation time into an ephemeral `/run/secrets/` tmpfs. `restic` writes AES-256 encrypted snapshots to a Backblaze B2 bucket over the S3-compatible endpoint. Two independent jobs run on a timer: `b2-critical` backs up configuration and secret-adjacent material, and `b2-data` backs up user files. Separating them allows independent retention policies and prevents a large user data backup from blocking the critical config backup.

---

## 4. User Layer — [`home/tco/`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/)

Home Manager runs inline within the system build, applied atomically on every rebuild. The user configuration covers package installation, dotfile deployment, shell environment, program configuration, and GTK theming — all expressed as declarative Nix code in [`home/tco/default.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix) and its imported modules (`packages/`, `hyprland/`, `dotfiles.nix`, `scripts/`, `shell.nix`, `gtk.nix`, `apps.nix`, `emacs.nix`).

**Dotfile strategy.** Most desktop configs are rendered into the Nix store from the [`hyprland-config`](https://github.com/RomeoCavazza/hyprland-config) flake input (`inputs.hypr-config`), with the palette injected at build time from [`lib/palette.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/lib/palette.nix) — so the theme stays consistent without runtime coordination. Two configs that are iterated on constantly (Neovim, Doom) are instead **out-of-store symlinks** pointing straight at the live checkout, so edits take effect with zero rebuild. The active source map:

```
~/.config/hypr    → store: hyprland-config repo + generated conf/tokens.conf   (home/tco/hyprland/config.nix)
~/.config/waybar  → store: hyprland-config waybar/ + scss/, dart-sass compiled (home/tco/hyprland/waybar.nix)
~/.config/rofi    → store: hyprland-config rofi/ + generated tokens.rasi        (home/tco/dotfiles.nix)
~/.config/foot    → store: hyprland-config foot/foot.ini                        (home/tco/dotfiles.nix)
~/.config/conky   → store: config/conky submodule + palette substitution        (home/tco/dotfiles.nix)
~/.config/nvim    → live symlink → <repo>/config/nvim   (mkOutOfStoreSymlink)
~/.config/doom    → live symlink → <repo>/config/doom   (mkOutOfStoreSymlink)
~/.local/bin/     → store: scripts from config/bin/ + hyprland-config bin/
```

**Session environment.** Qt applications are forced to Wayland (`QT_QPA_PLATFORM=wayland`) with Kvantum/qt6ct as the style engine. `~/.lmstudio/bin`, `~/.npm-global/bin`, and `~/.local/bin` are prepended to `$PATH`.

**User packages** are grouped by domain under [`home/tco/packages/`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages) — `cli.nix`, `dev.nix`, `desktop.nix`, `data.nix`, `monitoring.nix`, `session.nix`, `theme.nix`, `fun.nix`, plus domain toolchains in [`cad.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/cad.nix) (KiCad, FreeCAD), [`embedded.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/embedded.nix) (Arduino IDE/CLI, esptool, minicom), and [`data.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/data.nix) (DBeaver, database tooling).

**Hyprland plugins** are proper Nix derivations built under [`pkgs/hyprland-plugins/`](https://github.com/RomeoCavazza/nixos-config/blob/main/pkgs/hyprland-plugins) and linked into `~/.local/lib/` by [`home/tco/hyprland/plugins.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/hyprland/plugins.nix): `libhypr-darkwindow.so` (the [Hyprchroma](https://github.com/RomeoCavazza/hyprchroma) fork — adaptive inactive-window tint), `hypr-canvas.so`, and `hyprspace.so`.

**Shell:** Bash with a Starship prompt. The `rebuild` alias resolves to the wrapper script that records rebuild metrics for the Prometheus textfile collector.

---

## 5. Desktop Environment — Hyprland + Theme

Hyprland is a tiling Wayland compositor with XWayland enabled for X11 application compatibility. Its configuration is vendored from the [`hyprland-config`](https://github.com/RomeoCavazza/hyprland-config) repo and split into modular files under [`conf/`](https://github.com/RomeoCavazza/hyprland-config/tree/main/conf) (binds, layout, input, monitors, autostart, plugins, theme). At build time [`home/tco/hyprland/config.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/hyprland/config.nix) copies that tree into the store and writes a generated `conf/tokens.conf` from the shared palette. Five components extend the compositor: **Hyprspace** (workspace overview), **hyprtasking** (task manager), and **hyprland-plugins** (upstream set) are flake inputs; **hypr-canvas** (infinite canvas grouping) and **hypr-darkwindow/Hyprchroma** (adaptive tint shader) are built as derivations in [`pkgs/hyprland-plugins/`](https://github.com/RomeoCavazza/nixos-config/blob/main/pkgs/hyprland-plugins) and pinned by the lockfile for reproducibility.

The visual theme uses teal (`#94E2D5`) as its accent, defined once in [`lib/palette.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/lib/palette.nix) and rendered per tool by [`lib/colors.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/lib/colors.nix) — so the identity stays consistent across every component without coordination logic.

![Theme propagation](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/theme-flow.png)

[`conf/theme.conf`](https://github.com/RomeoCavazza/hyprland-config/blob/main/conf/theme.conf) sets border colors, rounding, blur parameters, and active/inactive window states, reading the accent from the generated `conf/tokens.conf`. Rofi uses [`rofi/custom/column-tco.rasi`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/custom/column-tco.rasi) for the sidebar layout and [`rofi/themes/apps-grid.rasi`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/themes/apps-grid.rasi) for the application grid, both fed a generated `tokens.rasi`. The foot terminal palette is tracked in [`foot/foot.ini`](https://github.com/RomeoCavazza/hyprland-config/blob/main/foot/foot.ini). GTK theme is Adwaita-dark with Papirus-Dark icons and Bibata-Modern-Ice cursor.

---

## 6. Waybar

Waybar is the Wayland status bar. Its sources live in the [`hyprland-config`](https://github.com/RomeoCavazza/hyprland-config/tree/main/waybar) repo and are materialized at build time by [`home/tco/hyprland/waybar.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/hyprland/waybar.nix): a `pkgs.runCommand` derivation copies the `waybar/` directory, injects the palette as `scss/_variables.scss`, and compiles [`style.scss`](https://github.com/RomeoCavazza/hyprland-config/blob/main/waybar/style.scss) through `dart-sass` into `style.css`. The compiled directory lands at `~/.config/waybar/` (store, not a raw symlink), and Waybar itself runs as a `systemd` user service tied to `graphical-session.target`. The layout is defined in [`config.jsonc`](https://github.com/RomeoCavazza/hyprland-config/blob/main/waybar/config.jsonc) and [`modules.json`](https://github.com/RomeoCavazza/hyprland-config/blob/main/waybar/modules.json).

Two runtime scripts drive the dynamic modules. [`WaybarCava.sh`](https://github.com/RomeoCavazza/hyprland-config/blob/main/waybar/WaybarCava.sh) generates a temporary Cava config on launch, pipes the raw output through character substitution and silence masking, and outputs unicode bar characters for the `custom/cava` module (its runtime dependencies are wrapped in via `wrapProgram`). [`activeapp.sh`](https://github.com/RomeoCavazza/hyprland-config/blob/main/waybar/activeapp.sh) queries `hyprctl activewindow` for the focused window's class, maps it to a Nerd Font icon, and outputs JSON for the active-window module.

---

## 7. Rofi

Rofi is rendered from the [`rofi/`](https://github.com/RomeoCavazza/hyprland-config/tree/main/rofi) tree in `hyprland-config` by [`home/tco/dotfiles.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/dotfiles.nix), which copies the theme, appends the generated `tokens.rasi`, and layers the declarative overrides. Two launch paths are active: the sidebar launcher runs via [`rofi/scripts/rofi-push.sh`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/scripts/rofi-push.sh), which shifts Hyprland's `gaps_out` to make room for the panel and restores the original gaps on close; the application grid runs via [`rofi/bin/rofi-grid.sh`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/bin/rofi-grid.sh). The sidebar uses [`column-tco.rasi`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/custom/column-tco.rasi) and the grid uses [`apps-grid.rasi`](https://github.com/RomeoCavazza/hyprland-config/blob/main/rofi/themes/apps-grid.rasi); both are wired from [`hyprland.conf`](https://github.com/RomeoCavazza/hyprland-config/blob/main/hyprland.conf) via the `$menu` and `$powermenu` variables.

---

## 8. Code Metrics

Generated with `cloc --vcs=git` over the tracked files of this repository (excludes `.git`, gitignored artifacts, and the vendored submodules, which are counted in their own repos). Full report: [`cloc-report.md`](./cloc-report.md).

| Language | Files | Code |
|---|---:|---:|
| HTML | 6 | 3924 |
| Nix | 96 | 2675 |
| JavaScript | 1 | 814 |
| Markdown | 10 | 807 |
| Bourne Again Shell | 12 | 420 |
| PlantUML | 8 | 344 |
| Text | 1 | 329 |
| Python | 1 | 70 |
| YAML | 3 | 67 |
| SVG | 4 | 14 |
| TOML | 1 | 6 |
| **Total** | **143** | **9 470** |

The HTML total is the Carbon TreeView code-map diagrams under [`docs/diagrams/carbon/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon); the Nix total covers the flake, profiles, system modules, and Home Manager. The C++ Hyprland plugin sources are not counted here — they live in the separate [`hyprchroma`](https://github.com/RomeoCavazza/hyprchroma), [`hyprspace`](https://github.com/RomeoCavazza/hyprspace), and [`hypr-canvas`](https://github.com/RomeoCavazza/hypr-canvas) fork repositories, fetched or locked by Nix during the build.
