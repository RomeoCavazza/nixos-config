# Documentation (annex)

The single source of truth for this repository is the [root README](../README.md). This folder holds annexes only: glossary, raw cloc report, and PlantUML diagrams.

---

## Tree of `docs/`

```
docs/
├── README.md           # this file
├── cloc-report.md      # raw cloc output
├── specification.txt   # dense configuration glossary
└── diagrams/
    ├── *.puml          # PlantUML sources (5 files)
    └── png/            # generated images (*.png)
```

---

## 1. Glossary (spec)

[**specification.txt**](./specification.txt) — Dense dictionary of the configuration: Nix options, paths, environment variables, commands, modules, diagrams. Alphabetical or thematic entries for quick lookup.

---

## 2. Raw cloc results

The [cloc](https://github.com/AlDanial/cloc) report is stored as produced. To regenerate from the repository root:

```bash
nix shell nixpkgs#cloc -c cloc . --exclude-dir=.git,node_modules,result,.direnv --md --out=docs/cloc-report.md
```

Full file: [**cloc-report.md**](./cloc-report.md).

---

## 3. PlantUML diagrams

Sources: `diagrams/*.puml`. Images: [**diagrams/png/**](./diagrams/png/). To regenerate PNGs from the repository root:

```bash
nix shell nixpkgs#plantuml -c plantuml -tpng -odocs/diagrams/png docs/diagrams/*.puml
```

---

### System overview

<img src="./diagrams/png/system-overview.png" width="100%" alt="System overview" />

The flake is the single entry point: it consumes inputs (nixpkgs, home-manager, rust-overlay, hyprchroma, nix-snapd) and produces the system configuration (configuration.nix, hardware-configuration.nix, modules), the user configuration (home/tco/home.nix), and dev shells (ai, embedded).

---

### Seaglass theme propagation

<img src="./diagrams/png/theme-flow.png" width="100%" alt="Theme flow" />

The Seaglass visual theme (accent #94E2D5) is applied in the config layer (Hyprland, Waybar, Rofi) and then in rendering (Foot, Hyprchroma, GTK/icons Adwaita-dark and Papirus-Dark).

---

### Boot and session choice

<img src="./diagrams/png/boot-session.png" width="100%" alt="Boot and session" />

At boot, systemd-boot then GDM allow choosing Hyprland (XWayland, Waybar, Rofi, Foot) or GNOME (Adwaita, Papirus).

---

### Module imports (configuration.nix)

<img src="./diagrams/png/module-deps.png" width="100%" alt="Module dependencies" />

configuration.nix imports hardware-configuration.nix and optional modules (nvidia-prime, virtualisation, emacs, science-data, launcher, starship, databases, ollama, nginx, observability). Optional links mainly concern hardware (nvidia-prime, virtualisation).

---

### Flake outputs

<img src="./diagrams/png/flake-outputs.png" width="100%" alt="Flake outputs" />

The flake exposes nixosConfigurations.nixos (full system config), homeConfigurations.tco (Home Manager), and devShells (ai: Python/pip/NVIDIA; embedded: Rust, gdb, openocd, Arduino, etc.).

---

## Files in `diagrams/`

| File | Purpose |
| ---- | ------- |
| **system-overview.puml** | Flake → System / User / Dev shells layers |
| **theme-flow.puml** | Seaglass theme propagation |
| **boot-session.puml** | Boot → GDM → Hyprland or GNOME |
| **module-deps.puml** | Module imports in configuration.nix |
| **flake-outputs.puml** | nixosConfigurations, homeConfigurations, devShells |
