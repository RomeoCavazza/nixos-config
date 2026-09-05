import tempfile
import unittest
import os
import base64
from pathlib import Path

from inbox import create_app
from inbox.database import get_db, init_db
from inbox.gmail_oauth import GmailOAuth
from inbox.gmail_mail import GmailMailProvider, normalize_gmail_message
from googleapiclient.errors import HttpError
from inbox.anthropic_assistant import AnthropicAssistant
from inbox.openai_assistant import OpenAIAssistant
from inbox.provider_errors import AssistantConfigurationError
from inbox.providers import get_assistant_provider, get_mail_provider


class FakeProvider:
    name = "fake"


class FakeResponses:
    def __init__(self, output):
        self.output = output
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        return type("Response", (), {"output_text": self.output})()


class FakeOpenAIClient:
    def __init__(self, output):
        self.responses = FakeResponses(output)


class FakeMessages:
    def __init__(self, output):
        self.output = output
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        block = type("TextBlock", (), {"type": "text", "text": self.output})()
        return type("Message", (), {"content": [block]})()


class FakeAnthropicClient:
    def __init__(self, output):
        self.messages = FakeMessages(output)


class FakeRequest:
    def __init__(self, payload):
        self.payload = payload

    def execute(self):
        if isinstance(self.payload, Exception):
            raise self.payload
        return self.payload


class FakeGmailService:
    def __init__(self, history, messages, full=None):
        self.history_payload = history
        self.message_payloads = messages
        self.full_payload = full or {"messages": []}

    def users(self):
        return self

    def history(self):
        return self

    def messages(self):
        return self

    def list(self, **kwargs):
        if "startHistoryId" in kwargs:
            return FakeRequest(self.history_payload)
        return FakeRequest(self.full_payload)

    def get(self, **kwargs):
        return FakeRequest(self.message_payloads[kwargs["id"]])

    def getProfile(self, **_kwargs):
        return FakeRequest({"historyId": "999"})


class InfrastructureTests(unittest.TestCase):
    def test_gmail_normalizes_plain_text_without_fetching_attachments(self):
        encoded = base64.urlsafe_b64encode("Hello Gmail".encode()).decode().rstrip("=")
        result = normalize_gmail_message({
            "id": "m1", "threadId": "t1", "historyId": "10",
            "internalDate": "1000", "labelIds": ["INBOX"], "snippet": "Hello",
            "payload": {"mimeType": "multipart/mixed", "headers": [
                {"name": "From", "value": "Ada <ada@example.com>"},
                {"name": "Subject", "value": "Test"},
            ], "parts": [
                {"mimeType": "text/plain", "filename": "", "body": {"data": encoded}},
                {"mimeType": "application/pdf", "filename": "file.pdf", "body": {"attachmentId": "a1"}},
            ]},
        })
        self.assertEqual(result["body"], "Hello Gmail")
        self.assertEqual(result["thread_external_id"], "t1")

    def test_gmail_incremental_sync_uses_history_cursor(self):
        message = {
            "id": "m2", "threadId": "t2", "historyId": "12", "internalDate": "2000",
            "labelIds": ["INBOX"], "snippet": "Changed", "payload": {"headers": []},
        }
        service = FakeGmailService({
            "history": [{"id": "12", "messagesAdded": [{"message": {"id": "m2"}}]}],
            "historyId": "12",
        }, {"m2": message})
        batch = GmailMailProvider("id", "secret", service=service).sync(
            {"refresh_token": "token", "history_id": "10"}, limit=25
        )
        self.assertEqual(batch.mode, "incremental")
        self.assertEqual(batch.history_id, "12")
        self.assertEqual([item["external_id"] for item in batch.messages], ["m2"])

    def test_expired_gmail_cursor_falls_back_to_bounded_full_sync(self):
        response = type("Response", (), {"status": 404, "reason": "Not Found"})()
        expired = HttpError(response, b'{"error":{"message":"expired"}}')
        message = {
            "id": "m3", "threadId": "t3", "historyId": "20", "internalDate": "3000",
            "labelIds": ["INBOX"], "snippet": "Full", "payload": {"headers": []},
        }
        service = FakeGmailService(expired, {"m3": message}, {"messages": [{"id": "m3"}]})
        batch = GmailMailProvider("id", "secret", service=service).sync(
            {"refresh_token": "token", "history_id": "1"}, limit=25
        )
        self.assertEqual(batch.mode, "full")
        self.assertEqual(batch.history_id, "999")
        self.assertEqual(batch.messages[0]["external_id"], "m3")
    def test_gmail_oauth_allows_http_only_during_loopback_exchange(self):
        oauth = GmailOAuth("client", "secret", "http://127.0.0.1:8000/callback")
        self.assertNotIn("OAUTHLIB_INSECURE_TRANSPORT", os.environ)

    def test_gmail_oauth_preserves_pkce_verifier_for_callback(self):
        oauth = GmailOAuth("client", "secret", "http://127.0.0.1:8000/callback")
        _url, _state, verifier = oauth.authorization_url()
        self.assertIsNotNone(verifier)
        self.assertGreaterEqual(len(verifier), 43)
        with oauth._allow_local_http():
            self.assertEqual(os.environ["OAUTHLIB_INSECURE_TRANSPORT"], "1")
        self.assertNotIn("OAUTHLIB_INSECURE_TRANSPORT", os.environ)

    def test_anthropic_provider_uses_structured_priority_output(self):
        client = FakeAnthropicClient(
            '[{"id":7,"score":78,"action":"Review today.","reason":"A deadline is stated."}]'
        )
        provider = AnthropicAssistant(None, "test-model", client=client)
        result = provider.analyze_priority({
            "id": 7,
            "sender_name": "Maya",
            "sender_email": "maya@example.com",
            "subject": "Review today",
            "snippet": "Please review.",
            "body": "Please review before 3 PM.",
        })
        self.assertEqual(result.score, 78)
        self.assertEqual(result.action, "Review today.")
        output_format = client.messages.calls[0]["output_config"]["format"]
        self.assertEqual(output_format["type"], "json_schema")
        self.assertEqual(client.messages.calls[0]["max_tokens"], 180)

    def test_anthropic_batches_priority_analysis_in_one_request(self):
        client = FakeAnthropicClient(
            '[{"id":1,"score":80,"action":"Reply.","reason":"Deadline."},'
            '{"id":2,"score":20,"action":"Read later.","reason":"No action."}]'
        )
        provider = AnthropicAssistant(None, "test-model", client=client)
        emails = [
            {"id": identifier, "sender_name": "Sender", "sender_email": "sender@example.com",
             "subject": f"Message {identifier}", "snippet": "Text", "body": "Text"}
            for identifier in (1, 2)
        ]
        results = provider.analyze_priorities(emails)
        self.assertEqual(set(results), {1, 2})
        self.assertEqual(len(client.messages.calls), 1)

    def test_anthropic_provider_requires_a_key_without_an_injected_client(self):
        with self.assertRaises(AssistantConfigurationError):
            AnthropicAssistant(None, "test-model")

    def test_openai_provider_parses_and_bounds_priority_output(self):
        client = FakeOpenAIClient(
            '{"score":82,"action":"Reply today.","reason":"A deadline is stated."}'
        )
        provider = OpenAIAssistant(None, "test-model", client=client)
        result = provider.analyze_priority({
            "sender_name": "Maya",
            "sender_email": "maya@example.com",
            "subject": "Review today",
            "snippet": "Please review.",
            "body": "Please review before 3 PM.",
        })
        self.assertEqual(result.score, 82)
        self.assertEqual(result.action, "Reply today.")
        self.assertFalse(client.responses.calls[0]["store"])

    def test_openai_provider_requires_a_key_without_an_injected_client(self):
        with self.assertRaises(AssistantConfigurationError):
            OpenAIAssistant(None, "test-model")

    def test_provider_factories_accept_test_doubles(self):
        assistant = FakeProvider()
        mail = FakeProvider()
        with tempfile.TemporaryDirectory() as directory:
            app = create_app({
                "TESTING": True,
                "DATABASE": str(Path(directory) / "test.sqlite3"),
                "ASSISTANT_PROVIDER": assistant,
                "MAIL_PROVIDER": mail,
            })
            with app.app_context():
                self.assertIs(get_assistant_provider(), assistant)
                self.assertIs(get_mail_provider(), mail)

    def test_migrations_are_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            app = create_app({
                "TESTING": True,
                "DATABASE": str(Path(directory) / "test.sqlite3"),
            })
            with app.app_context():
                init_db()
                init_db()
                versions = get_db().execute(
                    "SELECT version FROM schema_migrations"
                ).fetchall()
                self.assertEqual(
                    [row["version"] for row in versions],
                    ["001_initial.sql", "002_connected_accounts.sql", "003_gmail_sync.sql", "004_sync_integrity.sql"],
                )

    def test_production_requires_a_real_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "INBOX_SECRET"):
                create_app({
                    "TESTING": True,
                    "ENVIRONMENT": "production",
                    "SECRET_KEY": "dev-change-me",
                    "DATABASE": str(Path(directory) / "test.sqlite3"),
                })


if __name__ == "__main__":
    unittest.main()
