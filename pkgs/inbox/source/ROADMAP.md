# Inbox roadmap

This roadmap keeps the CS50x submission path small while leaving clean boundaries for a real Gmail mailbox, a live language model, and a NixOS service.

## Current baseline

The current application already provides:

- local authentication and user isolation;
- SQLite storage;
- inbox, pinned, archived, trash, priorities, search, rules, and JSON import;
- a separate message view;
- cached priority, summary, and suggested-reply results;
- a deterministic offline assistant for reliable demonstrations;
- semantic HTML that remains usable without CSS or JavaScript;
- one dependency-free minimal stylesheet.

Known architectural debt:

- Gmail refresh tokens and message bodies are intentionally stored in the local
  SQLite database and therefore depend on filesystem protection and backups;
- Gmail and JSON imports use separate result shapes rather than one shared type;
- provider calls have timeouts but no retry policy with jitter;
- there is no unattended synchronization scheduler.

## Submission path

### Run 1 — Minimal CSS

Status: complete.

Goal: make the established HTML readable without changing its information architecture.

Work:

- add one local stylesheet;
- use the system font stack;
- implement Gmail-like header, mailbox navigation, message rows, message view, settings, priorities, and auth;
- define only spacing, alignment, borders, text hierarchy, focus, hover, and responsive behavior;
- keep forms and navigation fully functional without JavaScript.

Constraints:

- no gradients, shadows, animations, marketing copy, decorative cards, remote fonts, or icon library;
- no HTML changes unless a layout relationship is genuinely missing;
- no more than one stylesheet.

Done when:

- all pages are readable at desktop and mobile widths;
- keyboard focus is visible;
- disabling the stylesheet leaves a fully usable application;
- a visual pass confirms that every visible element performs a task.

### Run 2 — Application boundaries and configuration

Status: complete.

Goal: remove hardcoded provider selection before adding external services.

Work:

- split authentication, mailbox, assistant, settings, and sync routes into blueprints;
- add repositories for emails, assistant results, and rules; add connected accounts with the Gmail schema in Run 4;
- define `AssistantProvider` and `MailProvider` protocols;
- create factories selected by Flask configuration;
- centralize environment parsing and fail securely outside development;
- replace broad exception handling during registration with explicit SQLite errors;
- introduce database migrations.

Configuration contract:

```text
INBOX_ENV=development|production
INBOX_SECRET=...
INBOX_DATABASE=...
INBOX_ASSISTANT=demo|openai|anthropic
INBOX_MAIL_PROVIDER=json|gmail
```

Done when:

- routes contain no provider construction and minimal SQL;
- tests can inject fake mail and assistant providers;
- demo mode continues to work without network access;
- a fresh database and an existing database reach the same schema through migrations.

### Run 3 — Live LLM provider

Status: complete. Anthropic summary, suggested reply, and batched priorities validated live with Claude Haiku 4.5.

Goal: replace deterministic generation with an optional real model while preserving offline demo mode.

Work:

- implement the provider using current official API documentation;
- request structured priority output and plain-text summary/reply output;
- validate output length, score range, and required fields;
- add timeouts and explicit authentication, rate-limit, provider, and malformed-output errors;
- cache successful results only;
- preserve previous results when regeneration fails;
- record provider and model metadata without storing the API key.

Environment:

```text
OPENAI_API_KEY=...
INBOX_OPENAI_MODEL=...
ANTHROPIC_API_KEY=...
INBOX_ANTHROPIC_MODEL=...
```

Done when:

- the same service tests pass against a fake provider;
- one opt-in live test covers priorities, summary, and reply;
- missing credentials produce a clear configuration error;
- the UI never claims demo output came from a live model.

### Run 4 — Gmail OAuth and read-only connection

Status: complete. Consent, refresh token, token renewal, and Gmail profile access validated live with the read-only scope.

Goal: connect one real Gmail mailbox without modifying it.

Work:

- create a Google Cloud OAuth client and callback route;
- use the smallest read-only Gmail scope initially;
- add a `connected_accounts` table;
- store OAuth state safely and protect against callback forgery;
- keep client secrets outside SQLite;
- decide and document refresh-token storage for the single-user NixOS deployment;
- expose Connect, Disconnect, and connection status in Settings.

Environment:

```text
GMAIL_CLIENT_ID=...
GMAIL_CLIENT_SECRET=...
GMAIL_REDIRECT_URI=http://127.0.0.1:8000/oauth/gmail/callback
```

Done when:

- authorization, callback, refresh, disconnect, denial, and expired-token paths are tested;
- a connected account can fetch its profile and no messages yet;
- no token or secret appears in logs, HTML, fixtures, or Git.

### Run 5 — Incremental Gmail synchronization

Status: complete for the bounded manual-sync scope. Full sync, Gmail history
delta, expired-cursor fallback, MIME normalization, provider-aware idempotent
upsert, sync runs, locking, and the Settings action are implemented. A background
scheduler remains an explicit non-goal before submission.

Goal: import a real inbox predictably and resume without duplication.

Work:

- add mailbox/provider/message/thread/history identifiers to the schema;
- implement Gmail message normalization behind `MailProvider`;
- fetch pages with a bounded page size and explicit maximum for manual sync;
- upsert by provider plus external ID;
- persist the sync cursor only after a successful page or completed run;
- add `sync_runs` with status, counts, cursor, and error summary;
- retain JSON import as a separate demo provider;
- add a manual Sync action in Settings, not a dashboard widget.

Done when:

- first sync, incremental sync, pagination, duplicate delivery, interruption, retry, and empty inbox are tested;
- rerunning sync does not duplicate messages;
- one mailbox can never read or mutate another user's rows;
- provider failures leave the last successful local state usable.

### Run 6 — Threads and Gmail state

Status: complete for read-only Gmail. Messages are grouped by Gmail thread,
displayed chronologically, summarized together, updated by incremental sync, and
locally archived/trashed as a thread. Remote Gmail state mutation remains out of
scope and no modify permission is requested.

Goal: display Gmail conversations and decide how local actions map to Gmail.

Work:

- group messages by thread and order replies chronologically;
- retain one row per thread in the inbox;
- map Gmail labels to inbox, archive, and trash semantics;
- start read-only, then request the modify scope only if remote archive/trash is enabled;
- make local-only pinning explicit unless it maps to Gmail stars;
- invalidate cached summaries when a thread changes.

Done when:

- thread summaries include all current messages;
- new replies update the existing thread instead of creating unrelated rows;
- local and remote state ownership is documented and tested;
- scope escalation is explicit rather than hidden in an OAuth refresh.

### Run 7 — Reply sending

Goal: turn a suggested draft into an intentional Gmail reply.

Work:

- keep generated text editable;
- create a draft or send only after a separate explicit user action;
- preserve Gmail thread and message headers;
- request the narrowest send-related OAuth scope;
- prevent duplicate sends with an idempotency record;
- record outbound metadata locally without pretending delivery is guaranteed.

Done when:

- draft creation is tested before direct sending is considered;
- the generated reply is never sent automatically;
- retries cannot send the same reply twice;
- provider errors retain the editable draft.

## Production path

### Run 8 — Reliability, security, and operations

Status: in progress. CSRF, secure production cookies, upload bounds, production
secret enforcement, localhost defaults, SQLite permissions, sync locking,
health/readiness, backups, and basic error preservation are implemented. Retry
with jitter, retention controls, and deeper structured logging remain.

- CSRF protection for all state-changing forms;
- secure cookies and production secret enforcement;
- request timeouts and bounded retries with jitter;
- structured logs with secret and email-body redaction;
- health and readiness endpoints;
- sync locking so two jobs cannot process the same mailbox concurrently;
- database backup and restore documentation;
- retention controls for cached assistant content;
- complete route, repository, provider, and isolation tests.

### Run 9 — NixOS service

Status: implemented and the complete Legion configuration builds successfully.
The reusable module provides a dynamic-user option; the host integration uses
the local `tco` account, Gunicorn, localhost binding, encrypted sops-nix
credentials, StateDirectory, restart policy, and sandboxing. Activation and the
restart test await one interactive `sudo nixos-rebuild switch`.

- production WSGI server rather than Flask debug server;
- Nix derivation or reproducible Python environment;
- systemd unit with `DynamicUser` or a dedicated restricted user;
- `StateDirectory` for SQLite and `LoadCredential` for secrets;
- explicit network, filesystem, and restart policy;
- optional timer for periodic Gmail sync;
- localhost binding by default;
- startup, restart, migration, credential rotation, and backup tests.

### Run 10 — CS50x delivery

Status: in progress. The 762-word README, AI disclosure, deterministic reset,
portable venv, backup documentation, showcase script, secret/size audit, and
offline suite are ready. The YouTube URL, final recording, repository commit
audit, submission form, explicit `submit50`, and gradebook check remain.

- complete a multi-paragraph README describing design decisions and file responsibilities;
- document third-party libraries, external APIs, and AI assistance;
- add setup instructions for demo mode and optional live mode;
- create a deterministic seed and reset command;
- run the complete offline test suite;
- rehearse a three-minute showcase covering the problem, inbox, priorities, summary, suggested reply, provider boundary, and original implementation;
- run `submit50 cs50/problems/2026/x/project` only after the final audit.

## Explicit non-goals before submission

The following `chekusu/mails` capabilities are valuable engineering references but unnecessary for this project:

- Cloudflare Email Routing Worker;
- Resend and fallback send-provider chains;
- hosted mailbox provisioning;
- multiple storage engines;
- attachment storage and text extraction;
- verification-code extraction;
- semantic or vector search;
- CLI and SDK distribution;
- multi-tenant hosted infrastructure.

The concepts worth borrowing are provider interfaces, incremental sync, transparent provider metadata, offline and live test separation, mailbox isolation, and idempotent local storage.

## Recommended order

For the shortest credible CS50x path:

```text
Run 1 → Run 2 → Run 3 → Run 4 → Run 5 → Run 10
```

Threads, remote mutation, sending, and the NixOS daemon can follow after submission unless the live showcase genuinely requires them:

```text
Run 6 → Run 7 → Run 8 → Run 9
```
