# Secrets

This directory contains `sops`-encrypted secrets that are safe to commit to the repository.

In this repository, [`../modules/core/secrets.nix`](../modules/core/secrets.nix)
configures `sops-nix`, then service modules read [`backup.yaml`](./backup.yaml)
and render the resulting secrets to runtime-only files under `/run/secrets`.

[`backup.yaml`](./backup.yaml) currently contains the Backblaze B2, Restic, and
Grafana secrets. Its values are encrypted with `sops`, the encrypted data key is
wrapped for the local machine runtime key, and decryption happens locally during
activation. So seeing [`backup.yaml`](./backup.yaml) in the repo is expected: the
file is encrypted, not plaintext, and the matching private keys stay outside
this repository.

What is safe to commit:

- `*.yaml` files encrypted with `sops`
- the repo policy file at [`../.sops.yaml`](../.sops.yaml)

What must stay local:

- decrypted secret files
- private Age keys
- private SSH keys
- `.env` files containing live credentials
