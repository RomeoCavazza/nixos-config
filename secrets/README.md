# Secrets

This directory contains `sops`-encrypted secrets that are safe to commit to the repository.

Current usage:

- [`../modules/backup.nix`](../modules/backup.nix) reads [`backup.yaml`](./backup.yaml) via `sops-nix`
- the resulting secrets are rendered to runtime-only files under `/run/secrets`
- `restic` uses those runtime files to authenticate to Backblaze B2

How this works here:

- [`backup.yaml`](./backup.yaml) contains the Backblaze B2 and Restic secrets
- values are encrypted with `sops`
- the encrypted data key is wrapped for the configured `age` recipient
- decryption happens locally during activation

In practice:

- seeing [`backup.yaml`](./backup.yaml) in the repo is expected
- the file is encrypted, not plaintext
- the matching private key is kept outside this repository

What is safe to commit:

- `*.yaml` files encrypted with `sops`
- the repo policy file at [`../.sops.yaml`](../.sops.yaml)

What must stay local:

- decrypted secret files
- private Age keys
- private SSH keys
- `.env` files containing live credentials
