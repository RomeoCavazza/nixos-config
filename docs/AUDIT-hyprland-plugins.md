# Audit Complet — Plugins Hyprland v0.54.2

*Généré le 2026-03-25 — Branche: `feat/hyprland-v054-upgrade`*

---

## Table des matières

1. [État actuel du système](#1-état-actuel-du-système)
2. [hypr-canvas — Audit technique approfondi](#2-hypr-canvas--audit-technique-approfondi)
3. [hyprchroma (darkwindow) — Audit de compatibilité](#3-hyprchroma-darkwindow--audit-de-compatibilité)
4. [HyprExpo vs Hyprtasking — Audit overview](#4-hyprexpo-vs-hyprtasking--audit-overview)
5. [VXWM — Le modèle à suivre](#5-vxwm--le-modèle-à-suivre)
6. [Plan d'action priorisé](#6-plan-daction-priorisé)

---

## 1. État actuel du système

### Ce qui fonctionne

| Composant | Status | Notes |
|-----------|--------|-------|
| Hyprland v0.54.2 | OK | Compilé depuis le flake, overlay en place |
| Dual-boot menu | OK | Timeout infini, entrée unique Windows 11 |
| hypr-canvas v0.1 | OK | Super+Scroll zoom, Super+Drag pan |
| HyprExpo | OK | Super+D, grille 1x5, bind fonctionnel |
| Waybar | OK | Autostart via exec-once |
| Thème seaglass | OK | Décors, animations, blur |

### Ce qui est désactivé

| Composant | Raison | Fichiers concernés |
|-----------|--------|-------------------|
| hyprchroma/darkwindow | `Textures.hpp` supprimé dans v0.54.2 | `flake.nix:16-18`, `home.nix:130-132`, `hyprland.conf:10-11` |
| dw-daemon | Dépend de hyprchroma | `hyprland.conf:29`, `home.nix:359-377` |
| dw-toggle-global | Dépend de hyprchroma | `hyprland.conf:110` |

### Fichiers modifiés (non commités)

- `flake.nix` — Hyprland v0.54.2 input + overlay, hyprchroma commenté
- `home/tco/home.nix` — hypr-canvas build inline, hyprexpo via hyprland-plugins, hyprchroma commenté
- `config/hypr/hyprland.conf` — plugins mis à jour, binds hyprexpo
- `flake.lock` — mis à jour avec les nouveaux inputs

---

## 2. hypr-canvas — Audit technique approfondi

### 2.1 Architecture

hypr-canvas (v0.1.0 par aaronsb) est un plugin Hyprland qui implémente un canvas infini via **12 hooks de fonctions** dans le pipeline de rendu, d'input et de protocole.

**Fichiers source** (`/home/tco/Projects/hypr-canvas/src/`) :
- `main.cpp` (17 lignes) — point d'entrée PLUGIN_INIT/PLUGIN_EXIT
- `canvas.hpp` (51 lignes) — état du canvas (zoom, offset) + hooks
- `canvas.cpp` (409 lignes) — toute la logique

### 2.2 Comment ça marche

Deux espaces de coordonnées :

```
Espace physique (écran)     Espace canvas (infini)
[0, largeur] × [0, hauteur]  →  [-∞, +∞] × [-∞, +∞]

canvasPos = offset + screenPos / zoom
screenPos = (canvasPos - offset) × zoom
```

Le zoom est ancré au curseur : quand tu scroll, le point sous ta souris reste fixe.

### 2.3 Les 12 hooks

| Hook | Rôle |
|------|------|
| `onMouseWheel` | Super+Scroll → zoom avec ancrage curseur |
| `onMouseButton` | Super+Click sur bureau vide → début pan |
| `onMouseMoved` | Delta souris → déplacement offset |
| `CPointerManager::position()` | Convertit coords physiques → canvas (16 call sites) |
| `closestValid()` | Désactive le clamping curseur aux bords du moniteur |
| `getMonitorFromCursor()` | Retourne toujours le moniteur focalisé en mode canvas |
| `getMonitorFromVector()` | Idem pour les lookups par position |
| `shouldRenderWindow()` | Force le rendu de TOUTES les fenêtres en mode zoom |
| `CRenderPass::render()` | Élargit la zone de dommage au viewport virtuel |
| `renderAllClientsForWorkspace()` | **LE hook principal** — applique translate+scale |
| `applyPositioning()` | Élargit les contraintes popup |
| `waylandToXWaylandCoords()` | Convertit canvas→physique pour XWayland |

### 2.4 Le problème du fond gris

**Ligne 220 de canvas.cpp :**

```cpp
g_pHyprOpenGL->clear(CHyprColor(0.1, 0.1, 0.1, 1.0));  // ← LE GRIS
```

Quand tu dézoomes, l'écran physique montre une zone plus grande que ton workspace.
Le `clear()` remplit tout le framebuffer en gris foncé AVANT de dessiner les fenêtres.
Résultat : tu vois ton bureau entier (wallpaper + waybar + fenêtres) rapetissé au milieu d'un océan gris.

### 2.5 Le vrai problème : TOUT bouge

Le hook `renderAllClientsForWorkspace` (ligne 236) applique la transformation à **l'intégralité du rendu** :

```cpp
original(self, pMonitor, pWorkspace, now, canvasTranslate, canvasScale);
```

`renderAllClientsForWorkspace` dessine :
- Les fenêtres ✓ (on veut que ça bouge)
- Le wallpaper ✗ (devrait rester fixe)
- Les surfaces layer-shell (waybar, dock) ✗ (devraient rester fixes)
- Les overlays ✗ (devraient rester fixes)

**C'est pour ça que waybar, le wallpaper et la dock bougent avec le canvas.**
La transformation est appliquée à un niveau trop haut — elle englobe tout.

### 2.6 Ce qui manque (zéro config, zéro dispatcher)

| Fonctionnalité manquante | Impact |
|--------------------------|--------|
| Dispatcher `canvas:reset` | Impossible de revenir à zoom=1.0 offset=0,0 sans recharger le plugin |
| Dispatcher `canvas:pan` | Pas de pan au clavier (VXWM a Super+Shift+Flèches) |
| Dispatcher `canvas:zoom` | Pas de zoom au clavier |
| Config `bg_color` | Fond gris hardcodé `(0.1, 0.1, 0.1)` |
| Config `zoom_min/max` | Hardcodé 0.05–1.0, pas de zoom-in au-delà de 1.0 |
| Config `zoom_step` | Hardcodé 1.15 |
| Config `modifier_key` | Hardcodé META/Super |
| Rendu séparé barres/wallpaper | Les barres et le fond bougent avec le canvas |

### 2.7 Plan de patch hypr-canvas

**Patch 1 — Dispatchers (rapide, ~50 lignes)**

Ajouter dans `main.cpp` via `HyprlandAPI::addDispatcher()` :
- `canvas:reset` → `zoom = 1.0; offset = {0,0};`
- `canvas:pan` → accepte `left/right/up/down` avec un pas configurable
- `canvas:zoom` → accepte `in/out`

Ça permet d'ajouter dans `hyprland.conf` :
```ini
bind = $mod, R, canvas:reset,
bind = $mod SHIFT, left,  canvas:pan, left
bind = $mod SHIFT, right, canvas:pan, right
bind = $mod SHIFT, up,    canvas:pan, up
bind = $mod SHIFT, down,  canvas:pan, down
```

**Patch 2 — Config values (rapide, ~30 lignes)**

Ajouter via `HyprlandAPI::addConfigValue()` :
```ini
plugin {
  hypr-canvas {
    bg_color = rgba(0a0a12ff)    # match ton thème seaglass
    zoom_min = 0.1
    zoom_max = 2.0               # permettre le zoom-in !
    zoom_step = 1.15
    pan_step = 100               # pixels par appui flèche
  }
}
```

**Patch 3 — Rendu séparé (complexe, ~100-200 lignes)**

C'est le vrai chantier. 3 approches possibles :

| Approche | Complexité | Résultat |
|----------|-----------|----------|
| **A. Dual-pass render** | Moyenne | Rendre les layers fixes d'abord, puis les fenêtres avec transform |
| **B. Per-window transform** | Haute | Itérer les fenêtres individuellement, transformer chacune |
| **C. Exclure les layer-shell** | Moyenne | Identifier les surfaces layer-shell et les soustraire de la transform |

**Approche recommandée : A (dual-pass)**

```
Pass 1 : wallpaper + layer-shell (identity transform)
Pass 2 : fenêtres uniquement (canvas transform : translate + scale)
Pass 3 : overlays layer-shell DESSUS (identity transform)
```

Le wallpaper et waybar restent fixes, seules les fenêtres se déplacent sur le canvas infini.

---

## 3. hyprchroma (darkwindow) — Audit de compatibilité

### 3.1 État du repo

- **Repo** : `github.com/alexhulbert/Hyprchroma` — 144 stars
- **Dernier commit** : fin 2024, pinné à Hyprland v0.45-v0.46
- **Maintenance** : **Abandonnée** — 0 issues ouvertes, 0 PRs, aucune mise à jour depuis ~2 ans
- **Fork connu** : AverageLinuxEnjoyer/HyprChromaNixFix → **N'EXISTE PAS**

### 3.2 Breaking changes entre v0.46 et v0.54.2

**4 catégories de cassures :**

#### 3.2.1 Système de shaders (CRITIQUE — le cœur du plugin)

Le fichier `TexturesDark.h` inclut :
```cpp
#include <hyprland/src/render/shaders/Textures.hpp>  // SUPPRIMÉ
```

**Ce qui a changé :**
- `Textures.hpp` (fichier monolithique avec tous les shaders inline) → **supprimé entièrement**
- Les shaders sont maintenant des fichiers `.glsl`/`.frag` individuels sous `src/render/shaders/glsl/`
- `SShader` struct → `CShader` class avec membres privés
- `useProgram()` → `useShader()`
- Sélection des shaders : au lieu de membres nommés (`m_shRGBA`, `m_shRGBX`, `m_shEXT`), c'est un tableau indexé par enum + bitmask de features (`getSurfaceShader(SH_FEAT_RGBA | SH_FEAT_ROUNDING | ...)`)
- Accès aux uniforms : `glGetUniformLocation(name)` → `getUniformLocation(eShaderUniform)` avec setters typés

**Impact** : Le mécanisme de swap de shaders (le cœur de hyprchroma — remplacer les shaders standard par des versions "dark") doit être **entièrement réécrit**.

#### 3.2.2 Système d'événements (MODÉRÉ)

- `registerCallbackDynamic()` → **déprécié, ne fait rien**
- Migration nécessaire vers `Event::bus()` (bus d'événements typé)
- Affecte les 4 subscriptions : `render`, `configReloaded`, `closeWindow`, `windowUpdateRules`

#### 3.2.3 API des dispatchers (MINEUR)

- `addDispatcher()` → `addDispatcherV2()` retournant `SDispatchResult`

#### 3.2.4 Renommage des membres (MINEUR mais partout)

- Code styling unification : `m_vWindows` → possible renommage, `m_szShortName` → idem
- Nécessite un search-and-replace guidé par les headers v0.54.2

### 3.3 Fichiers à modifier

| Fichier | Changements | Difficulté |
|---------|-------------|-----------|
| `TexturesDark.h` | Réécrire l'inclusion des shaders, adapter au format .glsl | HAUTE |
| `Helpers.h` | Adapter l'API CShader (uniforms, compilation) | HAUTE |
| `Helpers.cpp` | Réécrire `CompileShader`/`CreateProgram` avec `CShader::createProgram()` | HAUTE |
| `WindowInverter.cpp` | Migrer events, adapter le swap de shaders au système variant | HAUTE |
| `WindowInverter.h` | Mettre à jour les types | MOYENNE |
| `DecorationsWrapper.h` | Vérifier `IHyprWindowDecoration` signatures | BASSE |
| `main.cpp` | Migrer `addDispatcher` → `addDispatcherV2`, events → `Event::bus()` | BASSE |

### 3.4 Verdict

**C'est un chantier de 2-5 jours pour quelqu'un qui connaît les internals de Hyprland.**

Le problème principal n'est pas un header renommé — c'est que le **système de shaders a été complètement réarchitecturé**. L'ancien truc de "swap le shader RGBA par mon shader custom" ne marche plus avec le nouveau système de variants par bitmask.

**Recommandation** : Fork + port progressif. Utiliser les `hyprland-plugins` officiels (qui suivent chaque version) comme guide de migration. Le PR #12926 (shader refactor) et le PR #13333 (event bus) sont les deux références clés.

---

## 4. HyprExpo vs Hyprtasking — Audit overview

### 4.1 HyprExpo (ce que tu as actuellement)

**Config actuelle** (`hyprland.conf:159-166`) :
```ini
plugin {
  hyprexpo {
    columns = 5          # déjà en 1x5 ✓
    gap_size = 16
    bg_col = rgba(0a0a12ee)
    workspace_method = first 1
  }
}
```

**Ce qui marche** : Super+D → overview 1x5 de tes 5 workspaces

**Ce qui manque** :
- Pas de `skip_empty` visible dans ta config (mais la propriété existe, non testée)
- Pas de drag-and-drop de fenêtres entre workspaces
- Aperçus statiques (pas de previews live)
- Style basique, pas très configurable

### 4.2 Hyprtasking (alternative recommandée)

**Repo** : `github.com/raybbian/hyprtasking` — 290 stars, actif, supporte v0.54.0

| Feature | HyprExpo | Hyprtasking |
|---------|----------|-------------|
| Grille configurable | `columns` seulement | `rows` + `cols` |
| Layout 1x5 | Oui (columns=5) | Oui (rows=1, cols=5) |
| Previews live | Non | Oui |
| Drag-and-drop | Non | Oui |
| Layout linéaire (strip) | Non | Oui (mode `linear`) |
| Couleur de fond | `bg_col` | `bg_color` |
| Gestes tactiles | Non | Oui (3/4 doigts configurable) |
| Navigation clavier | Non | Oui (dispatchers directionnels) |
| Compatibilité v0.54 | Oui (via hyprland-plugins) | Oui |

**Config Hyprtasking équivalente** :
```ini
plugin {
  hyprtasking {
    layout = grid
    bg_color = 0xff0a0a12
    gap_size = 16
    border_size = 2
    grid {
      rows = 1
      cols = 5
      loop = false
    }
  }
}
```

### 4.3 Hyprspace (PAS recommandé)

- Layout horizontal fixe uniquement, pas de grille
- PR v0.54 ouvert mais **pas mergé** → ne compile pas
- Moins configurable que les deux autres

---

## 5. VXWM — Le modèle à suivre

### 5.1 Ce que fait VXWM

VXWM (`codeberg.org/wh1tepearl/vxwm`) est un WM X11 standalone (fork de dwm) qui implémente le canvas infini de manière radicalement différente de hypr-canvas.

**Approche VXWM** (~250 lignes de C) :
```
PAN : déplace physiquement TOUTES les fenêtres via XMoveWindow()
      Le moniteur est fixe, les fenêtres glissent en dessous
      Le wallpaper ne bouge JAMAIS
      La barre (dwm bar) ne bouge JAMAIS
```

**Approche hypr-canvas** (409 lignes de C++) :
```
PAN : transforme le RENDU ENTIER via SRenderModifData
      Les fenêtres, le wallpaper, waybar, TOUT rapetisse/se déplace
      L'écran entier s'éloigne dans un fond gris
```

### 5.2 Pourquoi VXWM a raison

| Aspect | VXWM | hypr-canvas |
|--------|------|-------------|
| Wallpaper | Fixe ✓ | Bouge ✗ |
| Barre de statut | Fixe ✓ | Bouge ✗ |
| Fond quand dézoomé | Pas de fond gris ✓ | Gris immonde ✗ |
| Zoom | Pas de zoom | Zoom + fond gris |
| UX | "Glisser sur un bureau infini" | "Mon écran rapetisse" |

### 5.3 L'objectif : reproduire VXWM dans Hyprland

Ce qu'on veut :
1. **Le wallpaper ne bouge jamais** — il remplit toujours l'écran
2. **Waybar ne bouge jamais** — toujours en haut de l'écran
3. **Seules les fenêtres se déplacent** sur un plan 2D infini
4. **Le focus centre automatiquement** la fenêtre focalisée (comme `centerwindow()` de VXWM)
5. **Super+Shift+Flèches** pour pan
6. **Super+R** pour retourner à l'origine (home canvas)
7. **Optionnel** : zoom doux avec wallpaper qui reste fixe

---

## 6. Plan d'action priorisé

### Phase 1 — Quick wins (aujourd'hui)

**1a. Patcher hypr-canvas : dispatchers + config**

Ajouter dans le source :
- `canvas:reset` dispatcher
- `canvas:pan` dispatcher (left/right/up/down)
- `canvas:zoom` dispatcher (in/out)
- Config `bg_color`, `pan_step`, `zoom_min`, `zoom_max`
- Changer la couleur de fond par défaut → `rgba(0a0a12ff)` (match seaglass)

Estimation : ~80 lignes de C++, 30 minutes.

**1b. Ajouter des binds dans hyprland.conf**

```ini
bind = $mod, R, canvas:reset,
bind = $mod SHIFT, left,  canvas:pan, left
bind = $mod SHIFT, right, canvas:pan, right
bind = $mod SHIFT, up,    canvas:pan, up
bind = $mod SHIFT, down,  canvas:pan, down
bind = $mod, minus,       canvas:zoom, out
bind = $mod, equal,       canvas:zoom, in
```

### Phase 2 — Rendu séparé (cette semaine)

**2a. Wallpaper et barres fixes pendant le pan/zoom**

Implémenter le dual-pass render dans `hkRenderAllClientsForWorkspace` :
1. Rendre le wallpaper + layers fixes en premier (identity transform)
2. Rendre les fenêtres avec la canvas transform
3. Rendre les overlays layer-shell par-dessus (identity transform)

C'est le changement architectural majeur. Estimation : ~150-200 lignes, 1-2 jours.

**2b. Focus-center (style VXWM)**

Quand on focus une fenêtre, ajuster `offset` pour la centrer à l'écran.
Hook `focusWindow` ou écouter l'event de focus.

### Phase 3 — Hyprchroma revival (semaine prochaine)

**3a. Fork alexhulbert/Hyprchroma**

```bash
git clone https://github.com/alexhulbert/Hyprchroma
cd Hyprchroma
git checkout -b feat/hyprland-v054
```

**3b. Portage par étapes :**

1. Fixer les headers → adapter `TexturesDark.h` aux nouveaux .glsl
2. Migrer le système d'events → `Event::bus()`
3. Réécrire le shader swap → nouveau système de variants
4. Mettre à jour les types et noms de membres
5. Tester

Estimation : 2-5 jours de travail.

### Phase 4 — Considérer Hyprtasking (optionnel)

Remplacer HyprExpo par Hyprtasking si tu veux :
- Live previews
- Drag-and-drop entre workspaces
- Gestes tactiles
- Layout linéaire (strip horizontal)

Sinon, HyprExpo avec `columns = 5` fait le job.

---

## Résumé exécutif

| Plugin | Status | Action | Priorité |
|--------|--------|--------|----------|
| **hypr-canvas** | Fonctionnel mais brut | Patcher : dispatchers + config + rendu séparé | P0 |
| **hyprchroma** | Cassé | Fork + port v0.54.2 (chantier shader) | P1 |
| **HyprExpo** | OK | Optionnel : remplacer par Hyprtasking | P2 |
| **PaperWM binds** | Pas commencé | Ajouter après canvas:pan | P2 |

**L'objectif final** : un desktop Hyprland où tu pan/zoom dans tes fenêtres comme sur une carte infinie, le wallpaper et waybar restent fixes, avec un `Super+R` pour revenir chez toi.
