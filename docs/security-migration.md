# Security Migration

> Scope: staged security hardening for the Legion workstation.
> Rule: observe first, debate second, implement in isolated runs only.

This file tracks the migration path for the security ideas borrowed from Securix without copying a full ANSSI-style baseline.

## Current State

Already implemented:

- `local-security-report.json`, available through `system.build.localSecurityReportDocument`;
- `local-security-check`, installed in the system profile after activation;
- pinned GitHub SSH host keys in `/etc/ssh/github_known_hosts`;
- explicit accepted risks for the bootloader generation count, Antigravity, broad Restic scope and Hyprland ownership;
- runtime observations for Secure Boot, TPM, root disk encryption and PAM U2F.

Not activated yet:

- Lanzaboote / Secure Boot signing;
- Disko disk layout migration;
- TPM2-bound secrets;
- U2F for sudo or login.

## Design Rule

Security reporting and security activation stay separate.

Reporting lives in:

```text
modules/security/local-report.nix
```

Future activation modules should stay split:

```text
modules/security/u2f.nix
modules/security/secure-boot.nix
modules/security/tpm2.nix
modules/disko/legion-v1.nix
```

The report can read and explain all decisions. Activation modules should only own one sensitive mechanism each.

## Run 0 - Cartography

Goal: understand the machine before mutating it.

Commands:

```bash
bootctl status
local-security-check
ls /dev/tpm0 /dev/tpmrm0
findmnt /
lsblk -f
```

Done when:

- Secure Boot state is known;
- TPM device presence is known;
- current root disk layout is documented;
- U2F recovery expectations are written before enforcement.

## Run 1 - U2F

Goal: add phishing-resistant local sudo hardening without locking out the operator.

Rules:

- start with sudo only, not graphical login;
- keep password fallback until the recovery path is tested;
- document where U2F mappings live;
- test one reboot before removing any fallback.

Rollback:

- boot a previous known-good system or edit the PAM module out from a recovery shell.

## Run 2 - Secure Boot Dry Run

Goal: prepare Lanzaboote without enrolling keys yet.

Rules:

- build and inspect the boot output first;
- document firmware state and current boot entries;
- do not mix with disk layout changes;
- keep an external recovery medium ready before enrollment.

## Run 3 - Lanzaboote Activation

Goal: enable Secure Boot signing once the dry run is understood.

Rules:

- one host only;
- one bootloader change only;
- no simultaneous kernel, Disko or TPM migration;
- verify boot, rollback, and `bootctl status` immediately.

## Run 4 - Disko VM

Goal: design the future disk layout without touching the workstation disk.

Rules:

- test destructive layout only in a VM first;
- run the installer or restore path twice;
- verify that mounts, LUKS/dm-crypt handles and temporary state are closed between runs;
- keep the test real or do not add it.

## Run 5 - Restore Drill

Goal: prove that Restic recovery works before trusting disk migration.

Rules:

- restore a representative subset;
- verify SSH/GPG/SOPS expectations;
- document key rotation after compromise;
- keep backup credentials out of the repo.

## Run 6 - Real Disk Migration

Goal: migrate disk layout only after VM and restore drills are boring.

Rules:

- full backup checked first;
- recovery medium ready;
- exact device names written down;
- no Secure Boot or TPM changes in the same run.

## Run 7 - TPM2

Goal: bind selected secrets only after boot and disk layout are stable.

Rules:

- start with non-critical material;
- keep an unsealed recovery path;
- document what is bound to PCR policy and why;
- never make Restic or SOPS unrecoverable from a hardware failure.

## Definition Of Done

The migration stays clean if:

- each run changes one sensitive mechanism at a time;
- every activation has a rollback note before it is applied;
- `nix flake check --no-build` passes;
- the system builds;
- `local-security-check` explains remaining warnings instead of hiding them.
