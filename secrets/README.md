# Secrets

This directory contains `sops`-encrypted secrets that are safe to commit to the repository.

What is safe to commit:

- `*.yaml` files encrypted with `sops`
- the repo policy file at [`../.sops.yaml`](../.sops.yaml)

What must never be committed:

- decrypted secret files
- private Age keys
- private SSH keys
- `.env` files containing live credentials

How this works in this repository:

- [`backup.yaml`](./backup.yaml) contains the Backblaze B2 and Restic secrets
- values are encrypted with `sops`
- the encrypted data key is wrapped for the configured `age` recipient
- decryption happens locally through `sops-nix` during activation

Important:

- seeing `secrets/backup.yaml` in the repo is expected
- the file is not plaintext and is not usable without the matching private key
- the local private key is not stored in this repository

Current usage:

- `modules/backup.nix` reads `backup.yaml` via `sops-nix`
- the resulting secrets are rendered to runtime-only files under `/run/secrets`
- `restic` then uses those runtime files to authenticate to Backblaze B2

If a credential was ever pasted in plaintext outside this encrypted workflow, rotate it.
