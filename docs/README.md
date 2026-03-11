# Documentation

The single source of truth for this repository is the [root README](../README.md). This folder holds annexes only: glossary, raw cloc report, and diagrams (Mermaid in this file; PNG exports in `diagrams/png/`).

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

## 1. Glossary

[**specification.txt**](./specification.txt) — Dense dictionary of the configuration by logical/technical grouping: Nix options, paths, environment variables, commands, modules, diagrams.

---

## 2. Raw cloc results

| Language | files | blank | comment | code |
| -------- | ----: | ----: | ------: | ---: |
| Bourne Again Shell | 40 | 310 | 250 | 1677 |
| Nix | 18 | 166 | 93 | 1174 |
| Markdown | 3 | 92 | 0 | 271 |
| Bourne Shell | 12 | 85 | 103 | 247 |
| Text | 1 | 79 | 0 | 208 |
| JSON | 1 | 13 | 0 | 137 |
| CSS | 2 | 30 | 20 | 125 |
| PlantUML | 5 | 23 | 0 | 94 |
| Lisp | 3 | 22 | 23 | 77 |
| INI | 1 | 7 | 0 | 33 |
| **SUM** | **86** | **827** | **489** | **4043** |

To regenerate from the repository root:

```bash
nix shell nixpkgs#cloc -c cloc . --exclude-dir=.git,node_modules,result,.direnv --md --out=docs/cloc-report.md
```

Full file: [**cloc-report.md**](./cloc-report.md).

---

## 3. Diagrams

Sources: `diagrams/*.puml`. PNG exports: [**diagrams/png/**](./diagrams/png/). To regenerate PNGs from the repository root:

```bash
nix shell nixpkgs#plantuml -c plantuml -tpng -odocs/diagrams/png docs/diagrams/*.puml
```

---

### System overview

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1e293b', 'secondaryColor': '#1e293b', 'tertiaryColor': '#1e293b', 'primaryBorderColor': '#888', 'lineColor': '#888', 'primaryTextColor': '#eee' }}}%%
flowchart LR
  inputs[Flake inputs]
  flake[flake.nix]
  system[System layer]
  user[User layer]
  shells[Dev shells]
  config[config/]

  inputs --> flake
  flake --> system
  flake --> user
  flake --> shells
  user --> config
```

The flake is the single entry point: it consumes inputs (nixpkgs, home-manager, rust-overlay, hyprchroma, nix-snapd) and produces the system configuration (configuration.nix, hardware-configuration.nix, modules), the user configuration (home/tco/home.nix), and dev shells (ai, embedded).

---

### Seaglass theme propagation

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1e293b', 'secondaryColor': '#1e293b', 'tertiaryColor': '#1e293b', 'primaryBorderColor': '#888', 'lineColor': '#888', 'primaryTextColor': '#eee' }}}%%
flowchart TB
  theme[Seaglass theme #94E2D5]
  hypr[Hyprland<br/>seaglass.conf, tokens.conf]
  waybar[Waybar<br/>mocha.css, style.css]
  rofi[Rofi<br/>column-tco.rasi]
  foot[Foot<br/>foot.ini]
  hyprchroma[Hyprchroma tint]
  gtk[GTK / Icons<br/>Adwaita-dark, Papirus-Dark]

  theme --> hypr
  theme --> waybar
  theme --> rofi
  hypr --> foot
  waybar --> hyprchroma
  rofi --> gtk
```

The Seaglass visual theme (accent #94E2D5) is applied in the config layer (Hyprland, Waybar, Rofi) and then in rendering (Foot, Hyprchroma, GTK/icons Adwaita-dark and Papirus-Dark).

---

### Boot and session choice

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1e293b', 'secondaryColor': '#1e293b', 'tertiaryColor': '#1e293b', 'primaryBorderColor': '#888', 'lineColor': '#888', 'primaryTextColor': '#eee' }}}%%
flowchart TB
  Boot[Boot]
  sb[systemd-boot]
  GDM[GDM]
  H[Hyprland + XWayland<br/>Waybar, Rofi, Foot]
  G[GNOME Desktop<br/>Adwaita, Papirus]

  Boot --> sb --> GDM
  GDM --> H
  GDM --> G
```

At boot, systemd-boot then GDM allow choosing Hyprland (XWayland, Waybar, Rofi, Foot) or GNOME (Adwaita, Papirus).

---

### Module imports (configuration.nix)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1e293b', 'secondaryColor': '#1e293b', 'tertiaryColor': '#1e293b', 'primaryBorderColor': '#888', 'lineColor': '#888', 'primaryTextColor': '#eee' }}}%%
flowchart TB
  subgraph config["configuration.nix"]
    hw[hardware-configuration.nix]
    nv[nvidia-prime.nix]
    virt[virtualisation.nix]
    emacs[emacs.nix]
    sci[science-data.nix]
    launcher[launcher.nix]
    starship[starship.nix]
    db[databases.nix]
    ollama[ollama.nix]
    nginx[nginx.nix]
    obs[observability.nix]
  end

  hw --> nv
  hw --> virt
  emacs --> sci --> launcher --> starship
  db --> ollama --> nginx --> obs
```

configuration.nix imports hardware-configuration.nix and optional modules (nvidia-prime, virtualisation, emacs, science-data, launcher, starship, databases, ollama, nginx, observability). Optional links mainly concern hardware (nvidia-prime, virtualisation).

---

### Flake outputs

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1e293b', 'secondaryColor': '#1e293b', 'tertiaryColor': '#1e293b', 'primaryBorderColor': '#888', 'lineColor': '#888', 'primaryTextColor': '#eee' }}}%%
flowchart LR
  subgraph flake["flake.nix"]
    nixos[nixosConfigurations.nixos]
    home[homeConfigurations.tco]
    shells[devShells.x86_64-linux]
  end

  sys[configuration.nix + modules]
  hm[home/tco/home.nix]
  ai[ai: python311, pip, nvidia]
  emb[embedded: rust, gdb, openocd, arduino]

  nixos --> sys
  home --> hm
  shells --> ai
  shells --> emb
```

The flake exposes nixosConfigurations.nixos (full system config), homeConfigurations.tco (Home Manager), and devShells (ai: Python/pip/NVIDIA; embedded: Rust, gdb, openocd, Arduino, etc.).
