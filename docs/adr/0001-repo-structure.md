# ADR 0001: Repository Structure

## Status

Accepted

## Context

The repository mixes several concerns:

- Nix flake inputs and outputs
- NixOS system configuration
- Home Manager user configuration
- dotfiles and theme assets
- operational documentation

Without clear boundaries, the setup becomes harder to reason about and riskier to evolve.

## Decision

The repository structure is organized around explicit responsibility boundaries:

- `flake.nix` defines pinned inputs, outputs, and development shells
- `configuration.nix` assembles the machine at system scope
- `modules/` contains optional or focused system capabilities
- `home/tco/home.nix` owns user-scoped packages and dotfiles
- `config/` stores reusable assets, themes, and scripts
- `docs/` stores technical documentation that should not overload the root `README.md`

## Consequences

### Positive

- easier navigation for future maintenance
- clearer ownership between system and user concerns
- better documentation discoverability
- simpler onboarding for readers of the repository

### Trade-offs

- more files to keep aligned
- requires discipline to avoid duplicating information
- some readers must move between `README.md` and `docs/`

## Follow-up

- keep feature modules isolated when adding new capabilities
- prefer generated reports for inventories and metrics
- add more ADRs when architectural choices become durable and non-trivial
