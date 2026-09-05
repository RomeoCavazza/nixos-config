PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS emails (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_id TEXT,
    sender_name TEXT NOT NULL,
    sender_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    snippet TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'Other',
    priority INTEGER NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 100),
    reason TEXT NOT NULL DEFAULT '',
    received_at TEXT NOT NULL,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0,
    is_trashed INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, external_id)
);

CREATE TABLE IF NOT EXISTS rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    field TEXT NOT NULL CHECK(field IN ('sender', 'subject')),
    value TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('prioritize', 'archive', 'category')),
    action_value TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS assistant_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email_id INTEGER NOT NULL REFERENCES emails(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK(kind IN ('priority', 'summary', 'reply')),
    content TEXT NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    score INTEGER CHECK(score BETWEEN 0 AND 100),
    provider TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, email_id, kind)
);

CREATE TABLE IF NOT EXISTS assistant_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK(kind = 'priorities'),
    provider TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_emails_user_received ON emails(user_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_emails_user_state ON emails(user_id, is_trashed, is_archived);
CREATE INDEX IF NOT EXISTS idx_assistant_priority ON assistant_results(user_id, kind, score DESC);
