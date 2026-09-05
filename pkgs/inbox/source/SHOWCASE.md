# Inbox showcase — maximum 3 minutes

## Opening frame — 0:00–0:12

Display all mandatory information before the demonstration:

- Inbox
- Romeo Cavazza
- GitHub username: RomeoCavazza
- edX username: verify before recording
- city and country: verify before recording
- recording date

## Problem and architecture — 0:12–0:30

Explain that Inbox is an original local email-triage application built with
Python, Flask, SQLite, JavaScript, Gmail's read-only API, and an interchangeable
assistant provider. State explicitly that it does not modify or send Gmail.

## Live Gmail and mailbox — 0:30–1:05

1. Open Settings and show the connected Gmail address and Sync button.
2. Click Sync and mention bounded first sync plus Gmail-history delta sync.
3. Return to Inbox and show search, one row per thread, and chronological thread
   messages.
4. Pin or locally archive one thread.

## Live assistant — 1:05–1:50

1. Open a real message.
2. Click Summarize; show the asynchronous body replacement and Show original.
3. Click Suggest reply; show that the draft is editable and never sent.
4. Open Priorities and run the batched analysis once if API credits permit.

## Original engineering — 1:50–2:30

Briefly show code or a prepared terminal:

- provider boundary for demo/Anthropic/OpenAI;
- Gmail OAuth PKCE and strict readonly scope;
- migrations and provider-aware upserts;
- CSRF, sync locking, SQLite permissions, and tests;
- NixOS Gunicorn service with systemd credentials.

Avoid displaying API keys, refresh tokens, `instance/inbox.env`, SQLite contents,
OAuth callback codes, or private email text in the terminal.

## Closing — 2:30–2:50

Summarize the result: a small, portable inbox that imports real Gmail safely,
groups conversations, and provides contextual AI without giving the model or the
application permission to alter the mailbox.

Keep ten seconds available for navigation delays. The final upload must be public
or unlisted, never private, and its URL must replace the TODO in `README.md`.
