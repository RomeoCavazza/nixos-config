# Hyprchroma

[![Build](https://github.com/RomeoCavazza/Hyprchroma/actions/workflows/build.yml/badge.svg)](https://github.com/RomeoCavazza/Hyprchroma/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/RomeoCavazza/Hyprchroma?display_name=tag)](https://github.com/RomeoCavazza/Hyprchroma/releases)

![2024-10-18-000536_hyprshot](https://github.com/user-attachments/assets/d47d78e7-5ddd-4637-83d4-6a8a7be2e0ce)

Hyprchroma is a Hyprland plugin that applies an adaptive chromakey tint while preserving readability and high-chroma UI elements.

> [!NOTE]
> This fork is a **v0.54.2 port and continuation** — the upstream plugin is incompatible with Hyprland ≥ v0.54 due to breaking API changes.
> See [Changes from upstream](#changes-from-upstream) for details.

## Configuration
```conf
# hyprland.conf

# Tint color (RGB, 0.0–1.0)
plugin:darkwindow:tint_r        = 0.20
plugin:darkwindow:tint_g        = 0.70
plugin:darkwindow:tint_b        = 1.00

# Tint opacity (0.0 = invisible, 1.0 = opaque)
plugin:darkwindow:tint_strength = 0.055

# Preserve bright and saturated pixels
plugin:darkwindow:protect_brights      = 1.00
plugin:darkwindow:bright_threshold     = 0.55
plugin:darkwindow:bright_knee          = 0.35
plugin:darkwindow:protect_saturated    = 1.00
plugin:darkwindow:saturation_threshold = 0.05
plugin:darkwindow:saturation_knee      = 0.25

# Apply tint on fullscreen windows (0 = no, 1 = yes)
plugin:darkwindow:enable_on_fullscreen = 0

# Tint every traced surface/subsurface (recommended)
plugin:darkwindow:tint_all_surfaces    = 1

# Briefly suspend tint after a workspace switch
plugin:darkwindow:suspend_on_workspace_switch_ms = 150
```

The values above are a recommended starting point, not the exact compiled defaults.

Also adds 2 dispatchers: `togglechromakey` (for the active window) and `darkwindow:shade address:0x<addr>` (per-window toggle)

## Installation

### Hyprland v0.54.2+ (NixOS)

#### Nix Flake
```nix
{
  inputs.hyprchroma.url = "github:RomeoCavazza/Hyprchroma";
  # ...
}
```

#### Home Manager (inline build)
```nix
hyprchroma-src = pkgs.writeText "main.cpp" (builtins.readFile ./pkgs/Hyprchroma-fork/src/main.cpp);
hypr-darkwindow = pkgs.stdenv.mkDerivation {
  pname   = "hypr-darkwindow";
  version = "3.3.1-v054";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ hyprland-pkg ] ++ hyprland-pkg.buildInputs;
  buildPhase = ''
    g++ -shared -fPIC -std=c++2b -O2 \
      $(pkg-config --cflags hyprland pixman-1 libdrm) \
      ${hyprchroma-src} -o libhypr-darkwindow.so
  '';
  installPhase = ''
    mkdir -p $out/lib
    cp libhypr-darkwindow.so $out/lib/
  '';
};
```

### Hyprpm
```sh
hyprpm add https://github.com/RomeoCavazza/Hyprchroma
hyprpm enable hyprchroma
hyprpm reload
```

### Manual Build
```sh
# Requires Hyprland v0.54.2 headers
make
hyprctl plugin load ./out/hyprchroma.so
```

## Changes from upstream

This fork began as a Hyprland v0.54.2 compatibility port. It now uses a grouped adaptive shader path that preserves bright and saturated pixels much better than a uniform overlay, while staying stable on dense dark interfaces.

```mermaid
flowchart LR
    A[Upstream Hyprchroma\npre-v0.54] --> B[v2.0.0-v054\ncompat rewrite]
    B --> C[v3.2.0-v054\nadaptive surface traversal]
    C --> D[v3.3.0-v054\ngrouped shader pass]
    D --> E[v3.3.1-v054\nworkspace-switch smoothing]
```

- Target: Hyprland `v0.54.2`
- Render path: grouped adaptive per-window shader pass with fallback overlay
- Surface handling: root surface + subsurfaces, composed in one guarded pass
- Pixel preservation: bright and saturated content stays readable
- Event model: modern `Event::bus()` listeners only
- New in `v3.3.1-v054`: brief configurable suspension after workspace switches to avoid stale tint carry-over during transitions, especially with Hyprspace

### Target environment
- Hyprland v0.54.2 (`59f9f268`)
- Hyprutils 0.11.0 / Hyprlang 0.6.8 / Aquamarine 0.10.0
- NixOS 26.05 (Yarara)

## Credits

- [alexhulbert/Hyprchroma](https://github.com/alexhulbert/Hyprchroma) — Original plugin
- [micha4w/Hypr-DarkWindow](https://github.com/micha4w/Hypr-DarkWindow) — Ancestor project

## Release Status

Current shipping target: `v3.3.1-v054`

## License

[MIT](LICENSE)
