This page is a reading map for the repository. It does not try to repeat every detail: the longer references live in [`docs/README.md`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/README.md), [`docs/specification.txt`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/specification.txt), and the modules themselves. The goal here is simple: know where to look, why each directory exists, and how the flake assembles the system.

Read the repository through three rules:

- [`flake.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.nix) and [`flake.lock`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.lock) are the build contract: inputs, pinned versions, and the NixOS output.
- [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix) builds the machine; Home Manager is embedded in that evaluation, so system and user state switch together.
- [`docs/diagrams/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/) contains the visual maps: PlantUML sources, Carbon-style TreeView HTML, and published PNGs.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/flake-outputs.png)

---

## Repository Root

![Root TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map.webp)

Generated HTML: [code-map.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map.html)

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

The root stays intentionally flat. The four top-level files define the machine: the [`flake.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.nix), its lockfile [`flake.lock`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.lock), the main [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix), and the detected [`hardware-configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/hardware-configuration.nix). The directories then split responsibility across system modules ([`modules/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/)), the user layer ([`home/`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/)), dotfiles ([`config/`](https://github.com/RomeoCavazza/nixos-config/blob/main/config/)), documentation ([`docs/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/)), and secrets ([`secrets/`](https://github.com/RomeoCavazza/nixos-config/blob/main/secrets/)).

[`flake.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/flake.nix) exposes one important output: `nixosConfigurations.nixos`. It evaluates [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix), injects the required modules, and embeds Home Manager inline. That design lets `nixos-rebuild switch` apply system and user state in the same activation.

---

## System Modules

![Modules TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map-modules.png)

Generated HTML: [code-map-modules.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map-modules.html)

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

[`modules/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/) is the system-only area. Each file adds one machine capability: GPU handling, virtualisation, local databases, observability, backups, services, or desktop integration. These modules are imported explicitly from [`hosts/legion/default.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix), except [`backup.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/backup.nix), which is injected by the flake together with `sops-nix` so secrets and Restic jobs stay in the same wiring layer.

[`edex.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/pkgs/apps/edex.nix) is an optional block. It remains documented and ready to connect, but it does not define the default machine behavior until it is imported.

---

## User Layer

![Home TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map-home.webp)

Generated HTML: [code-map-home.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map-home.html)

```text
/etc/nixos/home/tco/
├── home.nix
└── modules/
    └── apps/
        ├── cad.nix
        ├── data.nix
        └── embedded.nix
```

[`home/tco/home.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix) describes the user environment: packages, shell, themes, desktop entries, editors, and links to dotfiles. Home Manager uses the same `pkgs` instance as NixOS through `useGlobalPkgs = true`, avoiding two divergent package worlds.

The [`apps/`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/) modules group tools by work context. They remain user-only: they add applications and session configuration, not global daemons or drivers.

---

## Dotfiles and Scripts

![Config TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map-config.webp)

Generated HTML: [code-map-config.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map-config.html)

```text
/etc/nixos/config/
├── bin/
├── conky/
├── doom/
├── edex/
├── fastfetch/
├── foot/
├── grafana/
├── hypr/
├── icons/
├── nvim/
├── rofi/
├── scss/
├── swappy/
└── wal/
```

[`config/`](https://github.com/RomeoCavazza/nixos-config/blob/main/config/) contains the files used by the graphical session: scripts, themes, Hyprland, Waybar, Rofi, Foot, Neovim, Doom Emacs, and Grafana dashboards. Home Manager does not copy that logic into [`home.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix); it exposes these files into `$HOME` through symlinks or declared files.

This separation keeps [`home.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix) readable. Nix describes how files are linked into the user profile; [`config/`](https://github.com/RomeoCavazza/nixos-config/blob/main/config/) keeps the editable content in a normal Linux configuration tree.

---

## Documentation and Diagrams

![Docs TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map-docs.webp)

Generated HTML: [code-map-docs.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map-docs.html)

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

[`docs/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/) is the reading layer for the system. Wiki pages live in [`docs/wiki/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/wiki/), longer annexes live in [`docs/README.md`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/README.md), and the compact inventory lives in [`docs/specification.txt`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/specification.txt).

Diagrams are separated to avoid mixing source and rendered assets:

- [`docs/diagrams/puml/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/puml/) contains the PlantUML sources.
- [`docs/diagrams/carbon/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/) contains the TreeView HTML visualizer and its renderer.
- [`docs/diagrams/png/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/png/) contains the images published in the README and Wiki.

Other media stay in [`docs/assets/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/assets/): screenshots, logos, wallpapers, and Grafana snapshots. One intentional exception: [`https://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/assets/gdm-background.webp`](https://github.com/RomeoCavazza/nixos-config/blob/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/assets/gdm-background.webp) is also referenced by [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix) for the GDM wallpaper.

---

## Secrets

![Secrets TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/mainhttps://raw.githubusercontent.com/RomeoCavazza/assets/main/nixos-config/docs/diagrams/png/code-map-secrets.png)

Generated HTML: [code-map-secrets.html](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/code-map-secrets.html)

```text
/etc/nixos/secrets/
├── backup.yaml
└── README.md
```

[`secrets/`](https://github.com/RomeoCavazza/nixos-config/blob/main/secrets/) stays intentionally small. [`backup.yaml`](https://github.com/RomeoCavazza/nixos-config/blob/main/secrets/backup.yaml) is versioned because it is encrypted with SOPS/Age; useful values are only available at activation time through `sops-nix`. The local [`README`](https://github.com/RomeoCavazza/nixos-config/blob/main/secrets/README.md) explains how to manage this area without mixing secrets into system modules.

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

The renderer script lives at [`docs/diagrams/carbon/render-code-map.mjs`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/carbon/render-code-map.mjs). PlantUML sources live in [`docs/diagrams/puml/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/puml/) and output to [`docs/diagrams/png/`](https://github.com/RomeoCavazza/nixos-config/blob/main/docs/diagrams/png/).
