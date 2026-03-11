# Documentation annexe

La source de vérité du dépôt est le [README à la racine](../README.md). Ce dossier contient uniquement des annexes.

| Fichier / dossier | Description |
| ----------------- | ----------- |
| [**cloc-report.md**](./cloc-report.md) | Rapport [cloc](https://github.com/AlDanial/cloc) (lignes de code par langage). Régénérer avec : `nix shell nixpkgs#cloc -c cloc . --exclude-dir=.git,node_modules,result,.direnv --md --out=docs/cloc-report.md` |
| [**specification.txt**](./specification.txt) | Glossaire dense de la configuration (options Nix, chemins, variables, commandes). |
| [**diagrams/**](./diagrams/) | Diagrammes PlantUML : sources `.puml` à la racine de `diagrams/`, images générées dans [`diagrams/png/`](./diagrams/png/). Régénérer les PNG : `nix shell nixpkgs#plantuml -c plantuml -tpng -odocs/diagrams/png docs/diagrams/*.puml` |

## Contenu de `diagrams/`

- **system-overview.puml** — Flake → couches System / User / Dev shells  
- **theme-flow.puml** — Propagation du thème Seaglass (Hyprland, Waybar, Rofi, Foot, GTK)  
- **boot-session.puml** — Boot → GDM → Hyprland ou GNOME  
- **module-deps.puml** — Imports des modules dans `configuration.nix`  
- **flake-outputs.puml** — Outputs du flake (nixosConfigurations, homeConfigurations, devShells)
