# Secrets

This directory contains `sops`-encrypted secrets that are safe to commit to the repository.

In this repository, [`../modules/backup.nix`](../modules/backup.nix) reads
[`backup.yaml`](./backup.yaml) via `sops-nix`, renders the resulting secrets to
runtime-only files under `/run/secrets`, and lets `restic` use them to
authenticate to Backblaze B2.

[`backup.yaml`](./backup.yaml) contains the Backblaze B2 and Restic secrets.
Its values are encrypted with `sops`, the encrypted data key is wrapped for the
configured `age` recipient, and decryption happens locally during activation.
So seeing [`backup.yaml`](./backup.yaml) in the repo is expected: the file is
encrypted, not plaintext, and the matching private key stays outside this
repository.

What is safe to commit:

- `*.yaml` files encrypted with `sops`
- the repo policy file at [`../.sops.yaml`](../.sops.yaml)

What must stay local:

- decrypted secret files
- private Age keys
- private SSH keys
- `.env` files containing live credentials
