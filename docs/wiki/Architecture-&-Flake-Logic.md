This page is a reading map for the repository. It does not try to repeat every detail: the longer references live in `docs/README.md`, `docs/specification.txt`, and the modules themselves. The goal here is simple: know where to look, why each directory exists, and how the flake assembles the system.

Read the repository through three rules:

- `flake.nix` and `flake.lock` are the build contract: inputs, pinned versions, and the NixOS output.
- `configuration.nix` builds the machine; Home Manager is embedded in that evaluation, so system and user state switch together.
- `docs/diagrams/` contains the visual maps: PlantUML sources, Carbon-style TreeView HTML, and published PNGs.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/flake-outputs.png)

---

## Repository Root

![Root TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map.png)

Generated HTML: [code-map.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map.html)

```text
/etc/nixos/
├── flake.nix
├── flake.lock
├── configuration.nix
├── hardware-configuration.nix
├── modules/
├── home/
├── config/
├── docs/
└── secrets/
```

The root stays intentionally flat. The four top-level files define the machine: the flake, its lockfile, the main NixOS configuration, and the detected hardware configuration. The directories then split responsibility across system modules, the user layer, dotfiles, documentation, and secrets.

`flake.nix` exposes one important output: `nixosConfigurations.nixos`. It evaluates `configuration.nix`, injects the required modules, and embeds Home Manager inline. That design lets `nixos-rebuild switch` apply system and user state in the same activation.

---

## System Modules

![Modules TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-modules.png)

Generated HTML: [code-map-modules.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-modules.html)

```text
/etc/nixos/modules/
├── backup.nix
├── databases.nix
├── emacs.nix
├── gdm-wallpaper.nix
├── launcher.nix
├── nginx.nix
├── nvidia-prime.nix
├── observability.nix
├── ollama.nix
├── virtualisation.nix
├── edex.nix
├── lamp.nix
└── streamlit.nix
```

`modules/` is the system-only area. Each file adds one machine capability: GPU handling, virtualisation, local databases, observability, backups, services, or desktop integration. These modules are imported explicitly from `configuration.nix`, except `backup.nix`, which is injected by the flake together with `sops-nix` so secrets and Restic jobs stay in the same wiring layer.

`edex.nix`, `lamp.nix`, and `streamlit.nix` are optional blocks. They remain documented and ready to connect, but they do not define the default machine behavior until they are imported.

---

## User Layer

![Home TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-home.png)

Generated HTML: [code-map-home.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-home.html)

```text
/etc/nixos/home/tco/
├── home.nix
└── modules/
    └── apps/
        ├── cad.nix
        ├── data.nix
        └── embedded.nix
```

`home/tco/home.nix` describes the user environment: packages, shell, themes, desktop entries, editors, and links to dotfiles. Home Manager uses the same `pkgs` instance as NixOS through `useGlobalPkgs = true`, avoiding two divergent package worlds.

The `apps/` modules group tools by work context. They remain user-only: they add applications and session configuration, not global daemons or drivers.

---

## Dotfiles and Scripts

![Config TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-config.png)

Generated HTML: [code-map-config.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-config.html)

```text
/etc/nixos/config/
├── bin/
├── conky/
├── doom/
├── fastfetch/
├── foot/
├── grafana/
├── hypr/
├── nvim/
├── rofi/
├── scss/
├── swappy/
└── wal/
```

`config/` contains the files used by the graphical session: scripts, themes, Hyprland, Waybar, Rofi, Foot, Neovim, Doom Emacs, and Grafana dashboards. Home Manager does not copy that logic into `home.nix`; it exposes these files into `$HOME` through symlinks or declared files.

This separation keeps `home.nix` readable. Nix describes how files are linked into the user profile; `config/` keeps the editable content in a normal Linux configuration tree.

---

## Documentation and Diagrams

![Docs TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-docs.png)

Generated HTML: [code-map-docs.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-docs.html)

```text
/etc/nixos/docs/
├── README.md
├── cloc-report.md
├── specification.txt
├── assets/
├── diagrams/
│   ├── carbon/
│   ├── png/
│   └── puml/
└── wiki/
```

`docs/` is the reading layer for the system. Wiki pages live in `docs/wiki/`, longer annexes live in `docs/README.md`, and the compact inventory lives in `docs/specification.txt`.

Diagrams are separated to avoid mixing source and rendered assets:

- `docs/diagrams/puml/` contains the PlantUML sources.
- `docs/diagrams/carbon/` contains the TreeView HTML visualizer and its renderer.
- `docs/diagrams/png/` contains the images published in the README and Wiki.

Other media stay in `docs/assets/`: screenshots, logos, wallpapers, and Grafana snapshots. One intentional exception: `docs/assets/gdm-background.png` is also referenced by `configuration.nix` for the GDM wallpaper.

---

## Secrets

![Secrets TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-secrets.png)

Generated HTML: [code-map-secrets.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-secrets.html)

```text
/etc/nixos/secrets/
├── backup.yaml
└── README.md
```

`secrets/` stays intentionally small. `backup.yaml` is versioned because it is encrypted with SOPS/Age; useful values are only available at activation time through `sops-nix`. The local README explains how to manage this area without mixing secrets into system modules.

---

## Regeneration

TreeView screenshots are generated from the real repository structure:

```bash
node docs/diagrams/carbon/render-code-map.mjs
```

PlantUML diagrams are regenerated from their sources:

```bash
cd docs/diagrams/puml
nix shell nixpkgs#plantuml --command plantuml -tpng -o ../png ./*.puml
```

Wiki pages use `raw.githubusercontent.com` links for PNGs. Local paths such as `file:///etc/nixos/...` are intentionally avoided because they do not work on GitHub or in the published Wiki.
