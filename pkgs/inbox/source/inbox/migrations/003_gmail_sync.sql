ALTER TABLE emails ADD COLUMN provider TEXT NOT NULL DEFAULT 'json';
ALTER TABLE emails ADD COLUMN account_id INTEGER REFERENCES connected_accounts(id) ON DELETE CASCADE;
ALTER TABLE emails ADD COLUMN thread_external_id TEXT;
ALTER TABLE emails ADD COLUMN history_id TEXT;
ALTER TABLE emails ADD COLUMN label_ids TEXT NOT NULL DEFAULT '';

ALTER TABLE connected_accounts ADD COLUMN history_id TEXT;
ALTER TABLE connected_accounts ADD COLUMN last_synced_at TEXT;

CREATE TABLE sync_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id INTEGER NOT NULL REFERENCES connected_accounts(id) ON DELETE CASCADE,
    mode TEXT NOT NULL CHECK(mode IN ('full', 'incremental')),
    status TEXT NOT NULL CHECK(status IN ('running', 'complete', 'failed')),
    imported_count INTEGER NOT NULL DEFAULT 0,
    updated_count INTEGER NOT NULL DEFAULT 0,
    error_summary TEXT NOT NULL DEFAULT '',
    started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TEXT
);

CREATE INDEX idx_emails_provider_external
    ON emails(user_id, provider, external_id);
CREATE INDEX idx_sync_runs_account_started
    ON sync_runs(account_id, started_at DESC);
