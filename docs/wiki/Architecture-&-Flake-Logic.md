This page documents the structural decisions behind the flake and explains how the system and user configurations compose into a single atomic build.

![Architectural Scheme](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/scheme.png)

---

## The Flake as a Single Source of Truth

A Nix Flake is a specification: it declares inputs (external dependencies), their exact revisions, and the outputs derived from them. `flake.lock` records the resolved content-addressed hash for every input, making the entire dependency graph reproducible and auditable. There is no external state. No package manager running silently in the background. No configuration file written by an installer that lives outside version control. The pair of files — `flake.nix` for human-readable intent and `flake.lock` for the machine-generated exact hashes — is the complete description of what this system depends on.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/diagrams/flake-outputs.png)

---

## Input Resolution Strategy

The flake's ten inputs are organized by trust level, which determines how aggressively they are updated.

The base system tracks `nixos-unstable`. This gives access to current kernel versions, recent GPU drivers, and up-to-date toolchains. The tradeoff is occasional breakage on update, but this is mitigated by the lock file: updates only happen on an explicit `nix flake update`, never silently. A broken update is visible in `git diff flake.lock` and reversible by checking out the previous lock file.

Two packages are sourced from `nixos-24.11` via a custom overlay rather than from the unstable channel. Promtail — the log shipping agent — has a module-level option conflict with the current Loki version on unstable, and fixing it would require either forking the module or pinning Loki to an older version. The simpler solution is to use the stable channel's Promtail binary and run it as a raw systemd service, bypassing the NixOS module entirely. Guix, the GNU package manager, also requires a specific build environment that is more reliably available in the stable channel. Both packages are injected into the package set via a custom overlay so that the rest of the configuration sees them as ordinary packages with no special handling.

Hyprland is pinned to v0.54.2, and the custom plugins are pinned through RomeoCavazza GitHub forks. Hyprland plugin ABI is not stable between compositor versions — a plugin compiled against one commit of the Hyprland source tree will either crash or refuse to load when paired with a different commit. Pinning the forks through Nix inputs or fixed `fetchFromGitHub` revisions eliminates this class of failure while keeping the plugin sources maintained in their own repositories. The plugins are compiled during `nixos-rebuild` against the pinned Hyprland headers from the flake input — there are no binary downloads, no version assumptions, and no hidden local fork copies.

---

## System Layer

`configuration.nix` is the NixOS entry point. All optional system behaviors are extracted into discrete modules under `modules/` and activated via the `imports` list — adding or removing a service is a single line change.

![System architecture](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/diagrams/system-architecture.png)

---

## Overlay Composition

Before any module evaluates, three overlays are merged into the package set. The `rust-overlay` overlay injects Rust nightly and stable toolchains as first-class packages. The Hyprland overlay injects the compositor and its portal backend. The custom overlay pulls Promtail and Guix from the stable channel using `legacyPackages` rather than `packages` — this is intentional, because `legacyPackages` provides access to the full package set including non-free packages and packages that do not pass the strict evaluation checks that the `packages` output requires.

The order of overlay composition matters: later overlays can see and override the results of earlier ones. The custom overlay is last, which means it can reference the Hyprland overlay's output if needed without creating a dependency cycle.

---

## Home Manager — Inline Integration

Home Manager is embedded directly inside `nixosConfigurations` rather than being a standalone `homeConfigurations` output that is managed with a separate `home-manager switch` command. The consequence of this design is that `sudo nixos-rebuild switch` applies both the system configuration and the user configuration in a single atomic transaction.

If the system module fails to build, the user module does not activate. If the user module fails, the system does not switch. The two halves are either both applied or neither is — there is no intermediate state where the system is on generation N+1 and the user environment is still on generation N. This matters in practice because many configuration dependencies cross the system/user boundary: a system service might write a socket file that a user-space application connects to, or a system package might need to match the version expected by a user-space LSP client.

The `useGlobalPkgs = true` option makes Home Manager and the system share the same evaluated `nixpkgs` instance rather than evaluating it independently. This halves evaluation time on a rebuild and eliminates any possibility of package version divergence between what the system layer and the user layer consider to be, say, `pkgs.git`.

[See the diagram reference (User Layer)_](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/diagrams/user-layer.png)

---

## Build Flow and Activation

When `nixos-rebuild switch` runs, Nix evaluates the flake, resolves all inputs from the lock file, applies the overlays, evaluates `configuration.nix` and all imported modules, evaluates `home/tco/home.nix` through the inline Home Manager module, and builds the complete system closure. It then computes the difference between the current system at `/run/current-system` and the newly built closure, builds only what has changed, and activates the new system profile. Activation runs systemd's unit reload mechanism, which restarts only the services whose configuration actually changed. Finally, the new generation is registered as a boot entry in systemd-boot.

The bootloader is configured with `configurationLimit = 1`, which keeps exactly one NixOS entry in the systemd-boot menu. This limits disk usage from accumulated boot entries but means rollback via the boot menu is not available — rolling back requires either `sudo nixos-rebuild switch --rollback` from a live session, or reverting `flake.lock` to its previous state and rebuilding. The weekly automatic GC (`--delete-older-than 7d`) removes store paths older than seven days, but will never delete a path that the current system profile still references.

---

## specialArgs

The flake passes `specialArgs = { inherit inputs; }` to the NixOS system. This makes the entire inputs attrset available as a module argument throughout the module system — not just in `configuration.nix`, but in every module it imports. In practice this means any module can reference a flake input directly without threading it through overlays or extra package sets. This is used in `home.nix` to access the Hyprland plugin outputs from the vendored plugin flakes, and it keeps module files self-contained rather than requiring coordination with the overlay layer.

---

## Hardware Configuration

`hardware-configuration.nix` is the output of `nixos-generate-config`, run once at installation time and committed to the repository. It is intentionally not regenerated on rebuild — it is versioned code, subject to review and change like any other file. The hardware assumptions it encodes are explicit: Intel CPU with microcode updates enabled, EFI boot via systemd-boot, EXT4 root filesystem on NVMe, encrypted swap using a random key at boot (so swap does not persist across reboots), and the kernel modules needed for USB, Thunderbolt, and NVMe. GPU configuration is explicitly not in this file — it lives in `modules/nvidia-prime.nix`, where it can be documented and modified independently of the auto-generated hardware detection.

---

## Nix Store Hygiene

Two settings control the health of the local Nix store over time. `auto-optimise-store = true` replaces identical files in the store with hard links, which typically reduces store size by 15 to 30 percent on a machine with many generations and many packages that share common dependencies. This runs transparently on each build without any manual intervention.

The build sandbox is enabled with a custom build directory pointing to `/build`, which is a bind mount of `/home/nix-build`. This keeps large build artifacts — common when building Hyprland plugins or Rust projects from source — off the root partition while maintaining the sandbox isolation that prevents builds from accessing the network or the host filesystem during derivation evaluation.

---

## Repository Tree

```
/etc/nixos/                          (39 directories, 147 files)
├── flake.nix                        # Entry point: 10 inputs, overlay, nixosConfigurations + inline Home Manager
├── flake.lock                       # Content-addressed input hashes (never edited by hand)
├── configuration.nix                # Root NixOS config: imports, users, Nix runtime options, specialArgs
├── hardware-configuration.nix       # Generated by nixos-generate-config: CPU, EFI, NVMe, kernel modules
├── LICENSE
│
├── modules/                         # System-level NixOS modules
│   ├── backup.nix                   # Restic → Backblaze B2, two jobs: config files + user data
│   ├── databases.nix                # PostgreSQL 17+PostGIS, Redis, Qdrant
│   ├── edex.nix                     # FHS environment for eDEX-UI (inactive by default)
│   ├── emacs.nix                    # Emacs pgtk daemon, LSP tooling, TeXLive medium
│   ├── gdm-wallpaper.nix            # Patches gnome-shell-theme.gresource to set a custom GDM wallpaper
│   ├── lamp.nix                     # Apache + PHP + MariaDB dev stack (inactive by default)
│   ├── launcher.nix                 # gvfs, udisks2, Rofi, Waybar, Nemo
│   ├── nginx.nix                    # Localhost reverse proxy for dev services
│   ├── nvidia-prime.nix             # PRIME offload: Intel primary, NVIDIA on-demand, D3cold power-gating
│   ├── observability.nix            # Prometheus, Loki, Promtail (stable), Grafana
│   ├── ollama.nix                   # Ollama CUDA daemon: 32K context, 24h keep-alive
│   ├── streamlit.nix                # Streamlit app as sandboxed systemd service (inactive by default)
│   └── virtualisation.nix           # Docker, libvirt/KVM, QEMU, ARM64 binfmt
│
├── home/tco/
│   ├── home.nix                     # Home Manager entry: packages, dotfile symlinks, shell, GTK, Starship
│   ├── modules/apps/                # Optional HM modules: cad.nix, data.nix, embedded.nix
│
├── config/                          # Dotfiles symlinked into ~/.config/ by Home Manager
│   ├── bin/                         # User scripts on $PATH (hypr-layout-toggle, legion-pulse, waybar-toggle, …)
│   ├── conky/                       # Conky overlays: left/right panels + 16 metric scripts (GPU, net, disk, …)
│   ├── doom/                        # Doom Emacs: config.el, init.el, packages.el
│   ├── edex/settings.json           # eDEX-UI terminal settings
│   ├── fastfetch/config.jsonc       # Fastfetch system info layout
│   ├── foot/foot.ini                # Terminal: font, padding, Seaglass palette
│   ├── hypr/
│   │   ├── hyprland.conf            # Monitors, keybindings, window rules, autostart
│   │   ├── hypridle.conf            # Idle timeout and lock triggers
│   │   ├── hyprlock.conf            # Lock screen appearance
│   │   ├── theme/                   # seaglass.conf, hyprchroma.conf, rules.conf
│   │   └── waybar/                  # config.jsonc, modules.json, style.scss, mocha.css, WaybarCava.sh, activeapp.sh
│   ├── rofi/                        # config.rasi, theme.rasi, tokens.rasi + custom themes and launch scripts
│   ├── swappy/config                # Screenshot annotation tool config
│   └── wal/templates/               # Pywal palette templates for Hyprland and Foot
│
├── docs/
│   ├── README.md                    # Technical deep-dive (9 sections)
│   ├── cloc-report.md               # 107 files, 7 415 lines
│   ├── specification.txt            # Structured spec: inputs, outputs, modules, secrets
│   ├── assets/                      # Screenshots, hero GIF, wiki.png, gdm-background.png (13 files)
│   └── diagrams/
│       ├── *.puml                   # PlantUML sources (dark slate/teal theme)
│       ├── README.md                # Diagram index with embedded PNGs
│       └── png/                     # Generated PNGs referenced via raw GitHub URLs in wiki
│
├── secrets/
│   ├── backup.yaml                  # SOPS-encrypted: Backblaze creds and Restic passphrase
│   └── README.md                    # Secrets management notes
│
├── architecture.md                  # This file
└── README.md                        # Project overview and quick-start
```

The ownership split is strict: `modules/` is system-only, `home/tco/` is user-only, `config/` is dotfiles-only, `docs/` is never imported by any Nix file. You can read any subtree in isolation without needing to understand the whole.
