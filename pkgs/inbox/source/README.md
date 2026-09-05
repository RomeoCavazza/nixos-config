# Inbox

#### Video Demo: TODO — add the public or unlisted YouTube URL
#### Description:

Inbox is a focused email client and triage assistant built as an original CS50x
final project. It combines a server-rendered Flask application, SQLite, a
read-only Gmail connection, and an optional language-model provider. The goal is
not to replace Gmail: it is to provide a small local workspace where a user can
search, prioritize, summarize, pin, archive locally, and draft a possible reply.

The visual interface deliberately follows established mailbox conventions. It
uses semantic HTML, one small stylesheet, and a dependency-free JavaScript file.
The application remains usable without JavaScript; JavaScript progressively
enhances summary and suggested-reply actions with asynchronous JSON requests.

## Features

- local registration, authentication, and per-user row isolation;
- inbox, pinned, archived, trash, search, and configurable rules;
- deterministic JSON demo import and reset data;
- optional Anthropic or OpenAI summary, reply, and priority analysis;
- cached assistant results with provider/model metadata;
- Gmail OAuth with PKCE and the strict `gmail.readonly` scope;
- manual first sync of at most 25 inbox messages;
- incremental Gmail sync using the persisted history cursor;
- MIME plain-text/HTML normalization without attachment downloads;
- Gmail thread grouping with chronological message display;
- CSRF protection, bounded uploads, secure production cookies, and sync locking;
- SQLite migrations, health/readiness routes, backup helper, and NixOS module.

Inbox never sends, deletes, archives, labels, or otherwise modifies a Gmail
message. Archive, trash, and pin actions in this version are local SQLite state.
Suggested replies are editable text only and are never transmitted.

## Local setup

```bash
python -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python seed.py
.venv/bin/python run.py
```

Open <http://127.0.0.1:8000> and sign in with `user@example.com` / `sudo`.
`seed.py` is destructive: it resets the selected database to the eight-message
demo state. Demo mode performs no external request.

## Persistent local credentials

Run the interactive configurator once:

```bash
.venv/bin/python configure.py
```

It writes `instance/inbox.env` with mode `0600`. The entire `instance/`
directory is ignored by Git. Local values configure Anthropic and Gmail without
repeating shell exports. Production deliberately ignores this development file
and receives credentials from the service environment or systemd credentials.

For Gmail, create a Google OAuth Web client with this authorized redirect URI:

```text
http://127.0.0.1:8000/oauth/gmail/callback
```

The required values are `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, and the
read-only Gmail consent. Connect and synchronize from Settings. The first run
fetches a bounded inbox window; later runs request changes from Gmail history and
fall back to a full sync if Google expires the cursor.

Assistant providers are selected with `INBOX_ASSISTANT=demo|anthropic|openai`.
The live providers require `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`. Inputs are
treated as untrusted email data, successful results are cached, output lengths
are validated, and provider failures leave the last successful local result
intact.

## Architecture

- `inbox/views/` contains small Flask blueprints for auth, mailbox, assistant,
  settings, and Gmail requests.
- `inbox/repositories.py` owns SQLite queries, user scoping, thread grouping,
  assistant persistence, connected accounts, and sync runs.
- `inbox/gmail_oauth.py` implements OAuth state, PKCE, token exchange, and profile
  verification.
- `inbox/gmail_mail.py` implements bounded full/incremental reads and MIME
  normalization.
- `inbox/anthropic_assistant.py`, `inbox/openai_assistant.py`, and
  `inbox/assistant.py` implement interchangeable assistant providers.
- `inbox/services.py` contains deterministic classification and JSON
  normalization.
- `inbox/migrations/` upgrades fresh and existing SQLite databases.
- `inbox/templates/` provides the server-rendered interface;
  `inbox/static/` contains the only CSS and JavaScript.
- `tests/` covers routes, isolation, providers, MIME, migrations, CSRF, threads,
  synchronization, and deterministic services.

## Operations

`GET /healthz` checks the process and `GET /readyz` checks SQLite. Create an
online SQLite backup with:

```bash
.venv/bin/python backup.py backups/inbox.sqlite3
```

See `OPERATIONS.md` for restore instructions and the NixOS/Gunicorn service.
The production configuration requires a non-default `INBOX_SECRET`, uses secure
cookies, binds the supplied NixOS service to localhost, and stores state outside
the immutable source tree.

## Known limits

Gmail changes are read manually rather than on a background schedule. Incremental
runs are deliberately bounded and may require another click when many history
records accumulated. Gmail write scopes, sending, remote label mutation, hosted
multi-tenancy, attachment extraction, and vector search are explicit non-goals.

SQLite refresh tokens and imported email bodies remain sensitive local data.
The database, credential file, and backups must stay private and outside version
control.

## Third-party software and AI disclosure

The project uses Flask, Anthropic's Python SDK, OpenAI's Python SDK, Google's API
client, Google Auth OAuthlib, and their transitive dependencies. Gmail and live
LLM behavior require the corresponding external services and credentials.

AI assistance was used during design, implementation review, testing, and
documentation. The final project owner remains responsible for understanding the
code, demonstrating it, disclosing assistance according to the applicable CS50
policy, and submitting only work they are permitted to submit.
