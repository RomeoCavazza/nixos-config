# Secrets

This directory contains `sops`-encrypted secrets that are safe to commit to the repository.

In this repository, [`../modules/core/secrets.nix`](../modules/core/secrets.nix)
configures `sops-nix`, then service modules read [`backup.yaml`](./backup.yaml)
and render the resulting secrets to runtime-only files under `/run/secrets`.

[`backup.yaml`](./backup.yaml) contains the Backblaze B2, Restic, Grafana, and
declarative user password secrets. [`gitlab.yaml`](./gitlab.yaml) contains the
GitLab, Rails, ActiveRecord, runner, and SMTP secrets. Their values are encrypted
with `sops`; the encrypted data keys are wrapped for the current Legion host Age
recipient, and decryption happens locally during activation. Seeing these files
in the repository is expected: their values are ciphertext, while the matching
private key stays outside the repository at `/var/lib/sops-nix/key.txt` and is
persisted from `@persist`.

Most rendered secrets live under `/run/secrets`. The declarative user password
is decrypted earlier under `/run/secrets-for-users` so it exists before the
users/groups activation step.

What is safe to commit:

- `*.yaml` files encrypted with `sops`
- the repo policy file at [`../.sops.yaml`](../.sops.yaml)

What must stay local:

- decrypted secret files
- private Age keys
- private SSH keys
- `.env` files containing live credentials

The repository currently has one host recipient in [`../.sops.yaml`](../.sops.yaml).
Add a separately stored administrative recipient before treating the encrypted
repository as sufficient recovery material on its own.
