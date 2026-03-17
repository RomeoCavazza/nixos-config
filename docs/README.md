# Technical Deep Dive
Powered by Gemini

This folder contains the technical documentation annexes for the `setup-os` configuration. It focuses on the internal logic, architectural dependencies, and automated workflows that power the user interface.

---

## 1. System Architecture

```mermaid
graph TD
  User((User))
  Config[NixOS Configuration]
  Rofi[Rofi Launcher & Applets]
  RofiTheme[Rofi Theming & Display Mgmt]
  Waybar[Waybar Status Bar]
  Scripts[Dynamic Shell Scripts]
  Utils[Core System Utilities]
  Styling[Styling & Theming Assets]
  Hyprland[Hyprland Compositor]

  User --> Config
  User --> Rofi
  Config --> Rofi
  Config --> Waybar
  Config --> Scripts
  Config --> Hyprland
  Rofi --> RofiTheme
  Rofi --> Scripts
  RofiTheme --> Waybar
  RofiTheme --> Hyprland
  RofiTheme --> Styling
  Waybar --> Styling
  Scripts --> Styling
  Scripts --> Utils
  Utils --> Styling
  Utils --> Hyprland
  Hyprland <--> Scripts
```

This diagram illustrates the high-level relationship between the NixOS declarative layer and the dynamic runtime components (scripts, UI, and styling).

[Source: system-architecture.puml](./diagrams/system-architecture.puml) | [Export: system-architecture.png](./diagrams/png/system-architecture.png)

---

## 2. Seaglass Theme Propagation

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

The Seaglass visual theme (accent #94E2D5) is propagated from the config layer down to the rendering engines and GTK elements, ensuring a unified aesthetic.

[Source: theme-flow.puml](./diagrams/theme-flow.puml) | [Export: theme-flow.png](./diagrams/png/theme-flow.png)

---

## 3. Integration Logic

```mermaid
graph LR
  subgraph NixOS
    root[configuration.nix]
  end
  subgraph UI
    rofi[Rofi]
    waybar[Waybar]
    applets[Rofi Applets]
  end
  subgraph Backend
    scripts[Shell Scripts]
    styles[Styling CSS/Rasi]
  end

  root --> rofi
  root --> waybar
  rofi --> applets
  rofi --> styles
  applets --> styles
  applets --> scripts
  waybar --> styles
  waybar --> scripts
```

This visualization shows how `configuration.nix` acts as the orchestrator, integrating various UI components that in turn rely on shared shell scripts and styling assets.

[Source: integration-logic.puml](./diagrams/integration-logic.puml) | [Export: integration-logic.png](./diagrams/png/integration-logic.png)

---

## 4. Execution Flow: Launcher & Grid

```mermaid
sequenceDiagram
  participant L as launcher.sh
  participant C as colors.rasi
  participant R as Rofi
  participant G as rofi-grid.sh
  participant H as Hyprland
  participant W as Waybar

  L->>C: Randomize Accent
  L->>R: Launch Theme
  rect rgb(30, 41, 59)
    R->>G: Launch Grid Context
    G->>H: Blur Adjustment
    G->>W: Kill waybar
  end
  R->>G: Exit Context
  G->>H: Restore Blur
  G->>W: Relaunch waybar
```

This sequence documents the complex coordination required when launching the Rofi grid, including dynamic blur adjustment in Hyprland and process management for Waybar.

[Source: rofi-launcher-flow.puml](./diagrams/rofi-launcher-flow.puml) | [Export: rofi-launcher-flow.png](./diagrams/png/rofi-launcher-flow.png)

---

## 5. Flake Outputs

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
  ai[ai: python3, pydantic, nvidia]
  emb[embedded: rust, gdb, openocd, arduino]

  nixos --> sys
  home --> hm
  shells --> ai
  shells --> emb
```

The flake exposes the full system configuration, user-level Home Manager settings, and specialized development shells for AI and embedded work.

[Source: flake-outputs.puml](./diagrams/flake-outputs.puml) | [Export: flake-outputs.png](./diagrams/png/flake-outputs.png)
