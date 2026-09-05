import io
import json
import tempfile
import unittest
from pathlib import Path

from werkzeug.security import generate_password_hash

from inbox import create_app
from inbox.database import get_db
from inbox.gmail_mail import GmailBatch


class FakeGmailOAuth:
    def authorization_url(self):
        return "https://accounts.google.test/authorize", "safe-state", "safe-verifier"

    def exchange(self, authorization_response, state, code_verifier):
        if state != "safe-state" or code_verifier != "safe-verifier":
            raise ValueError("invalid state")
        return {
            "email": "ada@gmail.com",
            "refresh_token": "test-refresh-token",
            "scopes": "https://www.googleapis.com/auth/gmail.readonly",
        }


class FakeGmailMail:
    def sync(self, account, limit=25):
        return GmailBatch([{
            "external_id": "gmail-1", "thread_external_id": "thread-1",
            "history_id": "9", "label_ids": ["INBOX"], "sender_name": "Google",
            "sender_email": "google@example.com", "subject": "Imported from Gmail",
            "snippet": "A real-style message", "body": "Message body",
            "received_at": "2026-07-20T09:30:00", "is_archived": 0, "is_trashed": 0,
        }], "10")


class ApplicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        database = str(Path(self.temporary_directory.name) / "test.sqlite3")
        self.app = create_app({
            "TESTING": True, "SECRET_KEY": "test", "DATABASE": database,
            "ASSISTANT_PROVIDER": "demo",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db = get_db()
            first = db.execute(
                "INSERT INTO users(name,email,password_hash) VALUES(?,?,?)",
                ("Ada", "ada@example.com", generate_password_hash("test")),
            ).lastrowid
            second = db.execute(
                "INSERT INTO users(name,email,password_hash) VALUES(?,?,?)",
                ("Grace", "grace@example.com", generate_password_hash("test")),
            ).lastrowid
            db.execute(
                """INSERT INTO emails(user_id,external_id,sender_name,sender_email,subject,snippet,body,priority,received_at)
                VALUES(?,?,?,?,?,?,?,?,?)""",
                (first, "ada-1", "Maya", "maya@example.com", "Review today", "Please review.", "Please review before 3 PM.", 70, "2026-07-20T09:00:00"),
            )
            self.email_id = db.execute("SELECT id FROM emails WHERE external_id='ada-1'").fetchone()["id"]
            db.execute(
                """INSERT INTO emails(user_id,external_id,sender_name,sender_email,subject,received_at)
                VALUES(?,?,?,?,?,?)""",
                (second, "grace-1", "Private", "private@example.com", "Private message", "2026-07-20T08:00:00"),
            )
            self.other_email_id = db.execute("SELECT id FROM emails WHERE external_id='grace-1'").fetchone()["id"]
            db.commit()

    def tearDown(self):
        self.temporary_directory.cleanup()

    def login(self):
        return self.client.post("/login", data={"email": "ada@example.com", "password": "test"})

    def test_private_pages_require_login(self):
        for path in ("/dashboard", "/priorities", "/settings", f"/emails/{self.email_id}"):
            self.assertEqual(self.client.get(path).status_code, 302)

    def test_login_search_and_user_isolation(self):
        self.assertEqual(self.login().status_code, 302)
        page = self.client.get("/dashboard?q=Review")
        self.assertIn(b"Review today", page.data)
        self.assertNotIn(b"Private message", page.data)
        self.assertEqual(self.client.get(f"/emails/{self.other_email_id}").status_code, 404)

    def test_threads_have_one_inbox_row_and_show_each_message(self):
        with self.app.app_context():
            db = get_db()
            db.execute("UPDATE emails SET provider='gmail',thread_external_id='thread-a' WHERE id=?", (self.email_id,))
            db.execute(
                """INSERT INTO emails(user_id,provider,external_id,thread_external_id,sender_name,
                sender_email,subject,body,received_at) VALUES(?,?,?,?,?,?,?,?,?)""",
                (1, "gmail", "ada-2", "thread-a", "Maya", "maya@example.com",
                 "Re: Review today", "Second message", "2026-07-20T10:00:00"),
            )
            newest = db.execute("SELECT id FROM emails WHERE external_id='ada-2'").fetchone()["id"]
            db.commit()
        self.login()
        dashboard = self.client.get("/dashboard")
        self.assertNotIn(b">Review today</a>", dashboard.data)
        self.assertIn(b"Re: Review today", dashboard.data)
        detail = self.client.get(f"/emails/{newest}")
        self.assertIn(b"Please review before 3 PM", detail.data)
        self.assertIn(b"Second message", detail.data)

    def test_mailbox_action_and_assistant_results_persist(self):
        self.login()
        self.assertEqual(self.client.post(f"/emails/{self.email_id}/pin").status_code, 302)
        self.assertEqual(self.client.post(f"/emails/{self.email_id}/summarize").status_code, 302)
        self.assertEqual(self.client.post(f"/emails/{self.email_id}/suggest-reply").status_code, 302)
        page = self.client.get(f"/emails/{self.email_id}")
        self.assertIn(b"Unpin", page.data)
        self.assertIn(b"Summary", page.data)
        self.assertIn(b"Suggested reply", page.data)

    def test_assistant_endpoints_return_json_for_async_requests(self):
        self.login()
        headers = {"Accept": "application/json"}
        summary = self.client.post(
            f"/emails/{self.email_id}/summarize", headers=headers
        )
        reply = self.client.post(
            f"/emails/{self.email_id}/suggest-reply", headers=headers
        )
        self.assertEqual(summary.status_code, 200)
        self.assertEqual(reply.status_code, 200)
        self.assertIn("content", summary.get_json())
        self.assertIn("content", reply.get_json())

    def test_priorities_rules_and_json_import(self):
        self.login()
        self.assertEqual(self.client.post("/priorities/analyze").status_code, 302)
        self.assertIn(b"Review today", self.client.get("/priorities").data)
        self.client.post("/rules", data={"field": "sender", "value": "news", "action": "archive", "action_value": ""})
        payload = {"emails": [{"id": "new-1", "from": "News <news@example.com>", "subject": "Weekly"}]}
        response = self.client.post(
            "/import",
            data={"file": (io.BytesIO(json.dumps(payload).encode()), "mail.json")},
            content_type="multipart/form-data",
        )
        self.assertEqual(response.status_code, 302)
        self.assertIn(b"Weekly", self.client.get("/dashboard?view=archived").data)

    def test_missing_openai_key_is_a_user_facing_error(self):
        self.login()
        self.app.config.update(ASSISTANT_PROVIDER="openai", OPENAI_API_KEY=None)
        response = self.client.post(
            f"/emails/{self.email_id}/summarize", follow_redirects=True
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"OPENAI_API_KEY is not configured", response.data)

    def test_gmail_oauth_connect_callback_and_disconnect(self):
        self.login()
        self.app.config["GMAIL_OAUTH_SERVICE"] = FakeGmailOAuth()
        response = self.client.post("/oauth/gmail/connect")
        self.assertEqual(response.location, "https://accounts.google.test/authorize")

        response = self.client.get("/oauth/gmail/callback?state=safe-state&code=test")
        self.assertEqual(response.status_code, 302)
        settings = self.client.get("/settings")
        self.assertIn(b"ada@gmail.com", settings.data)
        self.assertNotIn(b"test-refresh-token", settings.data)

        self.client.post("/oauth/gmail/disconnect")
        self.assertNotIn(b"ada@gmail.com", self.client.get("/settings").data)

    def test_gmail_oauth_rejects_invalid_state_and_handles_denial(self):
        self.login()
        self.app.config["GMAIL_OAUTH_SERVICE"] = FakeGmailOAuth()
        self.client.post("/oauth/gmail/connect")
        self.assertEqual(
            self.client.get("/oauth/gmail/callback?state=wrong&code=test").status_code,
            400,
        )

        self.client.post("/oauth/gmail/connect")
        response = self.client.get(
            "/oauth/gmail/callback?error=access_denied", follow_redirects=True
        )
        self.assertIn(b"Gmail connection was cancelled", response.data)

    def test_gmail_sync_is_bounded_and_idempotent(self):
        self.login()
        with self.app.app_context():
            ConnectedAccountRepository = __import__(
                "inbox.repositories", fromlist=["ConnectedAccountRepository"]
            ).ConnectedAccountRepository
            ConnectedAccountRepository().upsert(
                1, "gmail", "ada@gmail.com", "refresh", "gmail.readonly"
            )
        self.app.config["GMAIL_MAIL_PROVIDER"] = FakeGmailMail()
        self.client.post("/oauth/gmail/sync")
        self.client.post("/oauth/gmail/sync")
        with self.app.app_context():
            rows = get_db().execute(
                "SELECT * FROM emails WHERE provider='gmail'"
            ).fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["subject"], "Imported from Gmail")
            account = get_db().execute(
                "SELECT * FROM connected_accounts WHERE provider='gmail'"
            ).fetchone()
            self.assertEqual(account["history_id"], "10")

    def test_csrf_is_required_outside_testing_mode(self):
        self.app.config.update(TESTING=False, CSRF_ENABLED=True)
        response = self.client.post("/login", data={"email": "ada@example.com", "password": "test"})
        self.assertEqual(response.status_code, 400)
        page = self.client.get("/login")
        with self.client.session_transaction() as session:
            token = session["csrf_token"]
        response = self.client.post(
            "/login", data={"email": "ada@example.com", "password": "test", "csrf_token": token}
        )
        self.assertEqual(response.status_code, 302)


if __name__ == "__main__":
    unittest.main()
