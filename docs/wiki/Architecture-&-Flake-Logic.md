Cette page sert de carte de lecture du dépôt. Elle ne cherche pas à tout redire: les détails longs vivent dans `docs/README.md`, `docs/specification.txt` et les modules eux-mêmes. Ici, l'objectif est simple: comprendre où regarder, pourquoi les dossiers existent, et comment la flake assemble le système.

Le dépôt se lit en trois règles:

- `flake.nix` et `flake.lock` sont le contrat de build: les inputs, les versions et la sortie NixOS.
- `configuration.nix` construit la machine; Home Manager est intégré dedans, donc système et utilisateur basculent ensemble.
- `docs/diagrams/` contient les cartes visuelles: sources PlantUML, HTML Carbon TreeView et PNG publiés.

![Flake structure](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/flake-outputs.png)

---

## Racine du dépôt

![Root TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map.png)

HTML généré: [code-map.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map.html)

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

La racine reste volontairement plate. Les quatre fichiers du haut définissent la machine: la flake, son lockfile, la configuration NixOS principale et la configuration matérielle détectée. Les dossiers séparent ensuite les responsabilités: modules système, couche utilisateur, dotfiles, documentation et secrets.

`flake.nix` expose une seule sortie importante: `nixosConfigurations.nixos`. Elle évalue `configuration.nix`, injecte les modules nécessaires, puis embarque Home Manager inline. C'est ce choix qui permet à `nixos-rebuild switch` d'appliquer système et utilisateur dans la même activation.

---

## Modules système

![Modules TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-modules.png)

HTML généré: [code-map-modules.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-modules.html)

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

`modules/` est la zone système pure. Chaque fichier ajoute une capacité de machine: GPU, virtualisation, bases locales, observabilité, backup, services ou intégration desktop. Ces modules sont importés explicitement depuis `configuration.nix`, sauf `backup.nix`, qui est injecté par la flake avec `sops-nix` pour garder les secrets et les jobs Restic dans le même câblage.

Les fichiers `edex.nix`, `lamp.nix` et `streamlit.nix` sont des blocs optionnels. Ils restent documentés et prêts à être branchés, mais ils ne définissent pas le comportement par défaut de la machine tant qu'ils ne sont pas importés.

---

## Couche utilisateur

![Home TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-home.png)

HTML généré: [code-map-home.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-home.html)

```text
/etc/nixos/home/tco/
├── home.nix
└── modules/
    └── apps/
        ├── cad.nix
        ├── data.nix
        └── embedded.nix
```

`home/tco/home.nix` décrit l'environnement utilisateur: paquets, shell, thèmes, entrées desktop, éditeurs et liens vers les dotfiles. Home Manager utilise le même `pkgs` que NixOS grâce à `useGlobalPkgs = true`, ce qui évite deux mondes de paquets divergents.

Les modules `apps/` regroupent les outils par contexte de travail. Ils restent utilisateur-only: ils ajoutent des logiciels et de la configuration de session, pas des daemons globaux ni des drivers.

---

## Dotfiles et scripts

![Config TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-config.png)

HTML généré: [code-map-config.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-config.html)

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

`config/` contient les fichiers réellement utilisés par la session: scripts, thèmes, configurations Hyprland, Waybar, Rofi, Foot, Neovim, Doom Emacs et dashboards Grafana. Home Manager ne recopie pas cette logique dans `home.nix`; il expose ces fichiers dans `$HOME` par symlinks ou fichiers déclarés.

Cette séparation garde `home.nix` lisible. Le Nix dit comment les fichiers sont reliés au profil utilisateur; `config/` garde le contenu éditable comme dans une configuration Linux classique.

---

## Documentation et diagrammes

![Docs TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-docs.png)

HTML généré: [code-map-docs.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-docs.html)

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

`docs/` est le support de lecture du système. Les pages wiki sont dans `docs/wiki/`, les annexes longues dans `docs/README.md`, et l'inventaire compact dans `docs/specification.txt`.

Les diagrammes sont rangés à part pour éviter le mélange:

- `docs/diagrams/puml/` contient les sources PlantUML.
- `docs/diagrams/carbon/` contient le visualiseur TreeView HTML et son script de génération.
- `docs/diagrams/png/` contient les images publiées dans README et Wiki.

Les autres médias restent dans `docs/assets/`: captures d'écran, logos, fonds et snapshots Grafana. Exception assumée: `docs/assets/gdm-background.png` est aussi référencé par `configuration.nix` pour le fond GDM.

---

## Secrets

![Secrets TreeView screenshot](https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/diagrams/png/code-map-secrets.png)

HTML généré: [code-map-secrets.html](https://github.com/RomeoCavazza/setup-os/blob/main/docs/diagrams/carbon/code-map-secrets.html)

```text
/etc/nixos/secrets/
├── backup.yaml
└── README.md
```

`secrets/` reste minimal exprès. `backup.yaml` est versionné parce qu'il est chiffré avec SOPS/Age; les valeurs utiles ne sont disponibles qu'au moment de l'activation via `sops-nix`. Le README local explique comment gérer cette zone sans mélanger les secrets avec les modules système.

---

## Régénération

Les captures TreeView sont générées depuis la structure réelle du dépôt:

```bash
node docs/diagrams/carbon/render-code-map.mjs
```

Les diagrammes PlantUML se régénèrent depuis leurs sources:

```bash
cd docs/diagrams/puml
nix shell nixpkgs#plantuml --command plantuml -tpng -o ../png ./*.puml
```

Les pages wiki utilisent des liens `raw.githubusercontent.com` vers les PNG. Les chemins locaux du type `file:///etc/nixos/...` sont volontairement évités, car ils ne fonctionnent ni dans GitHub ni dans le wiki publié.
