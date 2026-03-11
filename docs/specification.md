# Specification

## Purpose

`setup-os` is a personal NixOS workstation configuration designed to provision a reproducible desktop and development environment from a modular, declarative codebase.

## Goals

- Define the operating system with reproducible NixOS modules.
- Separate system configuration from user configuration with Home Manager.
- Support two desktop sessions: `Hyprland` and `GNOME`.
- Enable development workflows for AI, embedded, Rust, Python, Node.js, and shell tooling.
- Keep optional capabilities toggleable through dedicated modules.

## Non-goals

- Provide a generic one-size-fits-all NixOS distribution.
- Hide hardware-specific assumptions.
- Replace official NixOS or Home Manager documentation.

## System scope

The repository manages:

- NixOS base system settings
- bootloader and desktop session setup
- optional services via `modules/*.nix`
- user environment via `home/tco/home.nix`
- desktop theming and UI configuration under `config/`
- development shells exposed through the flake

The repository does not directly manage:

- machine secrets
- remote infrastructure
- application source code outside local workstation concerns

## Functional requirements

### FR-1 Reproducible system build

The repository must expose a `flake.nix` able to build a named `nixosConfiguration`.

### FR-2 Modular services

Optional features such as databases, observability, Ollama, virtualization, and theming integrations must be enabled through explicit module imports rather than monolithic inline configuration.

### FR-3 Split responsibilities

- `configuration.nix` owns system-level concerns.
- `home/tco/home.nix` owns user-level packages and dotfiles.
- `config/` stores reusable assets and dotfile sources.

### FR-4 Dual desktop support

The workstation must support both `GNOME` and `Hyprland` from GDM.

### FR-5 Developer workstation

The setup should provide:

- core CLI tools
- editor support
- shell utilities
- language servers
- optional dev shells for specialized workflows

### FR-6 Theme-driven UI customization

Hyprland, Waybar, Rofi, Foot, GTK, and plugin-related visual settings should remain coherent and modifiable through shared theme assets.

## Repository contracts

### Flake contract

`flake.nix` should continue to expose:

- `nixosConfigurations.nixos`
- `homeConfigurations.tco`
- `devShells.x86_64-linux.ai`
- `devShells.x86_64-linux.embedded`

### Module contract

Each module in `modules/` should encapsulate one concern and remain importable from `configuration.nix`.

### User environment contract

Home Manager should remain the single place for:

- home packages
- user session variables
- symlinked dotfiles
- user-scoped scripts

## Operational conventions

- Prefer small, composable modules.
- Prefer explicit imports over deeply nested conditional logic.
- Keep theme tokens centralized when possible.
- Keep hardware-specific tuning clearly documented.
- Document risky settings in prose near the relevant module or in `docs/architecture.md`.

## Suggested future extensions

- add `docs/adr/` for architecture decision records
- add generated package or module inventories when needed
- add CI validation for `nix flake check` or formatting/linting
