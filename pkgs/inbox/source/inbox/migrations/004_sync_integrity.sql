PRAGMA foreign_keys = OFF;

CREATE TABLE emails_rebuilt (
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
    provider TEXT NOT NULL DEFAULT 'json',
    account_id INTEGER REFERENCES connected_accounts(id) ON DELETE CASCADE,
    thread_external_id TEXT,
    history_id TEXT,
    label_ids TEXT NOT NULL DEFAULT '',
    UNIQUE(user_id, provider, external_id)
);

INSERT INTO emails_rebuilt
SELECT id,user_id,external_id,sender_name,sender_email,subject,snippet,body,
       category,priority,reason,received_at,is_pinned,is_archived,is_trashed,
       provider,account_id,thread_external_id,history_id,label_ids
FROM emails;

DROP TABLE emails;
ALTER TABLE emails_rebuilt RENAME TO emails;

CREATE INDEX idx_emails_user_received ON emails(user_id, received_at DESC);
CREATE INDEX idx_emails_user_state ON emails(user_id, is_trashed, is_archived);
CREATE INDEX idx_emails_provider_external ON emails(user_id, provider, external_id);
CREATE INDEX idx_emails_thread ON emails(user_id, provider, thread_external_id, received_at);
CREATE UNIQUE INDEX idx_one_running_sync_per_account
    ON sync_runs(account_id) WHERE status = 'running';

PRAGMA foreign_keys = ON;
