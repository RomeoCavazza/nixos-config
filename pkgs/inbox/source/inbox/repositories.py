from .database import get_db


class UserRepository:
    def find_by_email(self, email):
        return get_db().execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()

    def create(self, name, email, password_hash):
        db = get_db()
        cursor = db.execute(
            "INSERT INTO users(name,email,password_hash) VALUES(?,?,?)",
            (name, email, password_hash),
        )
        db.commit()
        return cursor.lastrowid


class EmailRepository:
    STATES = {
        "inbox": "is_archived=0 AND is_trashed=0",
        "pinned": "is_pinned=1 AND is_trashed=0",
        "archived": "is_archived=1 AND is_trashed=0",
        "trash": "is_trashed=1",
    }
    ACTIONS = {"pin": "is_pinned", "archive": "is_archived", "trash": "is_trashed"}

    def list(self, user_id, view="inbox", query=""):
        where = self.STATES.get(view, self.STATES["inbox"])
        params = [user_id]
        if query:
            where += " AND (sender_name LIKE ? OR sender_email LIKE ? OR subject LIKE ? OR snippet LIKE ?)"
            params.extend([f"%{query}%"] * 4)
        return get_db().execute(
            f"""SELECT * FROM (
                SELECT emails.*, ROW_NUMBER() OVER (
                    PARTITION BY COALESCE(thread_external_id, 'local:' || id)
                    ORDER BY received_at DESC, id DESC
                ) AS thread_rank, COUNT(*) OVER (
                    PARTITION BY COALESCE(thread_external_id, 'local:' || id)
                ) AS thread_count
                FROM emails WHERE user_id=? AND {where}
            ) WHERE thread_rank=1 ORDER BY is_pinned DESC, received_at DESC""",
            params,
        ).fetchall()

    def counts(self, user_id):
        return get_db().execute(
            """SELECT
                COUNT(DISTINCT CASE WHEN is_archived=0 AND is_trashed=0 THEN COALESCE(thread_external_id,'local:'||id) END) AS inbox,
                COUNT(DISTINCT CASE WHEN is_pinned=1 AND is_trashed=0 THEN COALESCE(thread_external_id,'local:'||id) END) AS pinned,
                COUNT(DISTINCT CASE WHEN is_archived=1 AND is_trashed=0 THEN COALESCE(thread_external_id,'local:'||id) END) AS archived,
                COUNT(DISTINCT CASE WHEN is_trashed=1 THEN COALESCE(thread_external_id,'local:'||id) END) AS trash
            FROM emails WHERE user_id=?""",
            (user_id,),
        ).fetchone()

    def find_owned(self, user_id, email_id):
        return get_db().execute(
            "SELECT * FROM emails WHERE id=? AND user_id=?", (email_id, user_id)
        ).fetchone()

    def thread(self, user_id, email_id):
        email = self.find_owned(user_id, email_id)
        if email is None:
            return []
        if not email["thread_external_id"]:
            return [email]
        return get_db().execute(
            """SELECT * FROM emails WHERE user_id=? AND provider=? AND thread_external_id=?
            ORDER BY received_at, id""",
            (user_id, email["provider"], email["thread_external_id"]),
        ).fetchall()

    def active(self, user_id):
        return get_db().execute(
            "SELECT * FROM emails WHERE user_id=? AND is_archived=0 AND is_trashed=0",
            (user_id,),
        ).fetchall()

    def toggle(self, user_id, email_id, action):
        column = self.ACTIONS.get(action)
        if column is None:
            return False
        db = get_db()
        target = self.find_owned(user_id, email_id)
        if target is None:
            return False
        value = int(not target[column])
        if action in {"archive", "trash"} and target["thread_external_id"]:
            cursor = db.execute(
                f"""UPDATE emails SET {column}=? WHERE user_id=? AND provider=?
                AND thread_external_id=?""",
                (value, user_id, target["provider"], target["thread_external_id"]),
            )
        else:
            cursor = db.execute(
                f"UPDATE emails SET {column}=? WHERE id=? AND user_id=?",
                (value, email_id, user_id),
            )
        db.commit()
        return cursor.rowcount == 1

    def import_many(self, user_id, emails, rules, classifier):
        db = get_db()
        count = 0
        for email in emails:
            analysis = classifier(email, rules)
            cursor = db.execute(
                """INSERT OR IGNORE INTO emails
                (user_id,external_id,sender_name,sender_email,subject,snippet,body,category,priority,reason,received_at,is_archived)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                (user_id, email["external_id"], email["sender_name"], email["sender_email"],
                 email["subject"], email["snippet"], email["body"], analysis["category"],
                 analysis["priority"], analysis["reason"], email["received_at"], analysis["is_archived"]),
            )
            count += cursor.rowcount
        db.commit()
        return count

    def upsert_gmail_many(self, user_id, account_id, emails, rules, classifier):
        db = get_db()
        imported = updated = 0
        for email in emails:
            analysis = classifier(email, rules)
            existing = db.execute(
                "SELECT id FROM emails WHERE user_id=? AND provider='gmail' AND external_id=?",
                (user_id, email["external_id"]),
            ).fetchone()
            values = (
                account_id, email["thread_external_id"], email["history_id"],
                " ".join(email["label_ids"]), email["sender_name"], email["sender_email"],
                email["subject"], email["snippet"], email["body"], analysis["category"],
                analysis["priority"], analysis["reason"], email["received_at"],
                email["is_archived"], email["is_trashed"],
            )
            if existing:
                db.execute(
                    """UPDATE emails SET account_id=?,thread_external_id=?,history_id=?,label_ids=?,
                    sender_name=?,sender_email=?,subject=?,snippet=?,body=?,category=?,priority=?,reason=?,
                    received_at=?,is_archived=?,is_trashed=? WHERE id=? AND user_id=?""",
                    values + (existing["id"], user_id),
                )
                updated += 1
            else:
                db.execute(
                    """INSERT INTO emails
                    (user_id,provider,external_id,account_id,thread_external_id,history_id,label_ids,
                    sender_name,sender_email,subject,snippet,body,category,priority,reason,received_at,
                    is_archived,is_trashed) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (user_id, "gmail", email["external_id"]) + values,
                )
                imported += 1
            if email["thread_external_id"]:
                db.execute(
                    """DELETE FROM assistant_results WHERE user_id=? AND email_id IN (
                    SELECT id FROM emails WHERE user_id=? AND provider='gmail' AND thread_external_id=?
                    )""",
                    (user_id, user_id, email["thread_external_id"]),
                )
        db.commit()
        return imported, updated

    def mark_gmail_removed(self, user_id, account_id, external_ids):
        if not external_ids:
            return 0
        db = get_db()
        placeholders = ",".join("?" for _ in external_ids)
        cursor = db.execute(
            f"""UPDATE emails SET is_archived=1,label_ids=''
            WHERE user_id=? AND account_id=? AND provider='gmail'
              AND external_id IN ({placeholders})""",
            (user_id, account_id, *external_ids),
        )
        db.commit()
        return cursor.rowcount

    def prepare_full_gmail_sync(self, user_id, account_id):
        db = get_db()
        db.execute(
            """UPDATE emails SET is_archived=1 WHERE user_id=? AND account_id=?
            AND provider='gmail'""",
            (user_id, account_id),
        )
        db.commit()


class RuleRepository:
    def list(self, user_id):
        return get_db().execute(
            "SELECT * FROM rules WHERE user_id=? ORDER BY id DESC", (user_id,)
        ).fetchall()

    def add(self, user_id, field, value, action, action_value=""):
        db = get_db()
        db.execute(
            "INSERT INTO rules(user_id,field,value,action,action_value) VALUES(?,?,?,?,?)",
            (user_id, field, value, action, action_value),
        )
        db.commit()

    def delete(self, user_id, rule_id):
        db = get_db()
        db.execute("DELETE FROM rules WHERE id=? AND user_id=?", (rule_id, user_id))
        db.commit()


class AssistantRepository:
    def for_email(self, user_id, email_id):
        results = get_db().execute(
            "SELECT * FROM assistant_results WHERE user_id=? AND email_id=?",
            (user_id, email_id),
        ).fetchall()
        return {row["kind"]: row for row in results}

    def priorities(self, user_id):
        return get_db().execute(
            """SELECT assistant_results.*, emails.sender_name, emails.subject
            FROM assistant_results JOIN emails ON emails.id=assistant_results.email_id
            WHERE assistant_results.user_id=? AND assistant_results.kind='priority'
              AND assistant_results.score>=50 AND emails.is_archived=0 AND emails.is_trashed=0
            ORDER BY assistant_results.score DESC, emails.received_at DESC""",
            (user_id,),
        ).fetchall()

    def last_priorities_run(self, user_id):
        return get_db().execute(
            "SELECT * FROM assistant_runs WHERE user_id=? AND kind='priorities' ORDER BY id DESC LIMIT 1",
            (user_id,),
        ).fetchone()

    def save(self, user_id, email_id, kind, content, provider, reason="", score=None):
        db = get_db()
        db.execute(
            """INSERT INTO assistant_results(user_id,email_id,kind,content,reason,score,provider)
            VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id,email_id,kind) DO UPDATE SET
              content=excluded.content,reason=excluded.reason,score=excluded.score,
              provider=excluded.provider,created_at=CURRENT_TIMESTAMP""",
            (user_id, email_id, kind, content, reason, score, provider),
        )
        db.commit()

    def record_priorities_run(self, user_id, provider):
        db = get_db()
        db.execute(
            "INSERT INTO assistant_runs(user_id,kind,provider) VALUES(?,?,?)",
            (user_id, "priorities", provider),
        )
        db.commit()


class ConnectedAccountRepository:
    def find(self, user_id, provider):
        return get_db().execute(
            "SELECT * FROM connected_accounts WHERE user_id=? AND provider=?",
            (user_id, provider),
        ).fetchone()

    def upsert(self, user_id, provider, email, refresh_token, scopes):
        db = get_db()
        existing = self.find(user_id, provider)
        if existing is not None and existing["email"].lower() != email.lower():
            db.execute(
                "DELETE FROM emails WHERE user_id=? AND account_id=? AND provider=?",
                (user_id, existing["id"], provider),
            )
        db.execute(
            """INSERT INTO connected_accounts(user_id,provider,email,refresh_token,scopes)
            VALUES(?,?,?,?,?) ON CONFLICT(user_id,provider) DO UPDATE SET
              email=excluded.email,refresh_token=excluded.refresh_token,
              scopes=excluded.scopes,
              history_id=CASE WHEN connected_accounts.email=excluded.email
                THEN connected_accounts.history_id ELSE NULL END,
              last_synced_at=CASE WHEN connected_accounts.email=excluded.email
                THEN connected_accounts.last_synced_at ELSE NULL END,
              updated_at=CURRENT_TIMESTAMP""",
            (user_id, provider, email, refresh_token, scopes),
        )
        db.commit()

    def delete(self, user_id, provider):
        db = get_db()
        db.execute(
            "DELETE FROM connected_accounts WHERE user_id=? AND provider=?",
            (user_id, provider),
        )
        db.commit()

    def record_sync(self, user_id, account_id, history_id):
        db = get_db()
        db.execute(
            """UPDATE connected_accounts SET history_id=?,last_synced_at=CURRENT_TIMESTAMP,
            updated_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=?""",
            (history_id, account_id, user_id),
        )
        db.commit()


class SyncRunRepository:
    def start(self, user_id, account_id, mode):
        db = get_db()
        cursor = db.execute(
            "INSERT INTO sync_runs(user_id,account_id,mode,status) VALUES(?,?,?,'running')",
            (user_id, account_id, mode),
        )
        db.commit()
        return cursor.lastrowid

    def complete(self, run_id, imported, updated):
        db = get_db()
        db.execute(
            """UPDATE sync_runs SET status='complete',imported_count=?,updated_count=?,
            finished_at=CURRENT_TIMESTAMP WHERE id=?""",
            (imported, updated, run_id),
        )
        db.commit()

    def set_mode(self, run_id, mode):
        db = get_db()
        db.execute("UPDATE sync_runs SET mode=? WHERE id=?", (mode, run_id))
        db.commit()

    def fail(self, run_id, summary):
        db = get_db()
        db.execute(
            """UPDATE sync_runs SET status='failed',error_summary=?,
            finished_at=CURRENT_TIMESTAMP WHERE id=?""",
            (summary[:200], run_id),
        )
        db.commit()
