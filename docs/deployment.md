# Deployment And Operations

## Purpose

This document describes how to apply, validate, and recover the workstation configuration.

## Preconditions

- NixOS installed on the target machine
- flakes enabled
- repository cloned locally
- hardware assumptions reviewed before applying

## Standard apply flow

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

## Suggested bootstrap flow

```bash
sudo cp -r /etc/nixos /etc/nixos-backup
sudo git clone https://github.com/RomeoCavazza/setup-os.git /etc/nixos-new
sudo cp -r /etc/nixos-new/* /etc/nixos/
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

## Validation checklist

After a rebuild, validate at least:

- boot menu still appears and the system boots correctly
- GDM starts
- both `GNOME` and `Hyprland` sessions are available
- audio and Bluetooth still function
- NVIDIA or graphics acceleration still function as expected
- Home Manager files are present in the user session
- key tools open correctly

## Dry-run and review workflow

Prefer a review step before applying larger changes:

```bash
cd /etc/nixos
sudo nixos-rebuild dry-run --flake .#nixos
```

You can also inspect the flake structure with:

```bash
nix flake show
```

## Rollback strategy

If a rebuild introduces a regression:

- reboot and select a previous generation from the bootloader if available
- or use a previous known-good repository state and rebuild again

Because rollback strategy is generation-based, avoid deleting working generations too aggressively until changes are validated.

## Development shells

Two main shells are currently exposed:

- `nix develop .#ai`
- `nix develop .#embedded`

Use them to isolate toolchains instead of globally widening the base system unless the tool is needed system-wide.

## Operational advice

- keep machine-specific tweaks documented near the relevant module
- prefer additive module changes over editing unrelated sections inline
- test desktop, graphics, and login flows after changes that touch display or session logic
