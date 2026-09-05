# Inbox operations

## Local development

Run `configure.py` once, then start the development server with
`.venv/bin/python run.py`. The local credential file and SQLite database live in
`instance/`, are ignored by Git, and are restricted to the current user.

## Backup and restore

Create a consistent online backup with:

```bash
.venv/bin/python backup.py backups/inbox.sqlite3
```

Stop Inbox before restoring. Preserve the current database, copy the selected
backup to `instance/inbox.sqlite3`, set mode `0600`, then start Inbox and check
`/readyz`. Never place backups in Git.

## NixOS

Import `nix/inbox.nix` and configure the four credential paths as shown in
`nix/example.nix`. The module runs Gunicorn on localhost, creates
`/var/lib/inbox` with mode `0700`, loads secrets through systemd credentials,
and applies basic systemd sandboxing. Copy the project to the path referenced by
`services.inbox.source` or replace it with a flake/store source.

After rebuilding, verify:

```bash
curl --fail http://127.0.0.1:8000/healthz
curl --fail http://127.0.0.1:8000/readyz
systemctl status inbox
```

The Gmail sync remains an explicit authenticated action in Settings. There is
no unattended timer and no Gmail write scope.

The example binds plain HTTP exclusively to `127.0.0.1` and therefore sets
`INBOX_SECURE_COOKIES=0`. If a TLS reverse proxy exposes the service, remove
that override so production cookies retain the Secure attribute.
