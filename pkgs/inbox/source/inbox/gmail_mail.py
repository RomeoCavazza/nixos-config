import base64
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parseaddr
from html.parser import HTMLParser

from flask import current_app
from google.auth.exceptions import GoogleAuthError
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from .gmail_oauth import GMAIL_READONLY_SCOPE


class GmailSyncError(RuntimeError):
    """Safe failure raised while reading Gmail."""


@dataclass(frozen=True)
class GmailBatch:
    messages: list[dict]
    history_id: str | None
    mode: str = "full"
    removed_ids: tuple[str, ...] = ()


class _HTMLText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)

    def text(self):
        return " ".join(" ".join(self.parts).split())


def _decode(data):
    if not data:
        return ""
    padded = data + "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(padded).decode("utf-8", errors="replace")


def _body(payload):
    plain = []
    html = []

    def visit(part):
        if part.get("filename"):
            return
        mime = part.get("mimeType", "")
        data = part.get("body", {}).get("data")
        if data and mime == "text/plain":
            plain.append(_decode(data))
        elif data and mime == "text/html":
            parser = _HTMLText()
            parser.feed(_decode(data))
            html.append(parser.text())
        for child in part.get("parts", []):
            visit(child)

    visit(payload or {})
    return "\n\n".join(plain).strip() or "\n\n".join(html).strip()


def normalize_gmail_message(message):
    payload = message.get("payload", {})
    headers = {
        header.get("name", "").lower(): header.get("value", "")
        for header in payload.get("headers", [])
    }
    sender_name, sender_email = parseaddr(headers.get("from", ""))
    received = datetime.fromtimestamp(
        int(message.get("internalDate", "0")) / 1000, timezone.utc
    ).replace(tzinfo=None).isoformat(timespec="seconds")
    labels = message.get("labelIds", [])
    return {
        "external_id": message["id"],
        "thread_external_id": message.get("threadId"),
        "history_id": message.get("historyId"),
        "label_ids": labels,
        "sender_name": sender_name or sender_email or "Unknown sender",
        "sender_email": sender_email,
        "subject": headers.get("subject") or "(no subject)",
        "snippet": message.get("snippet", ""),
        "body": _body(payload) or message.get("snippet", ""),
        "received_at": received,
        "is_archived": int("INBOX" not in labels),
        "is_trashed": int("TRASH" in labels),
    }


class GmailMailProvider:
    name = "gmail"

    def __init__(self, client_id, client_secret, service=None):
        self.client_id = client_id
        self.client_secret = client_secret
        self.service = service

    def sync(self, account, limit=25):
        try:
            service = self.service or self._service(account["refresh_token"])
            if account["history_id"]:
                try:
                    return self._incremental(service, account["history_id"], limit)
                except HttpError as error:
                    if getattr(error.resp, "status", None) != 404:
                        raise
            return self._full(service, limit)
        except (GoogleAuthError, HttpError, KeyError, ValueError) as error:
            raise GmailSyncError("Gmail sync failed. Reconnect the account and retry.") from error

    def _full(self, service, limit):
        messages = []
        page_token = None
        while len(messages) < limit:
            page = service.users().messages().list(
                userId="me", labelIds=["INBOX"],
                maxResults=min(10, limit - len(messages)), pageToken=page_token,
            ).execute()
            for item in page.get("messages", []):
                messages.append(self._get(service, item["id"]))
                if len(messages) == limit:
                    break
            page_token = page.get("nextPageToken")
            if not page_token or len(messages) == limit:
                break
        profile = service.users().getProfile(userId="me").execute()
        return GmailBatch(messages, profile.get("historyId"))

    def _incremental(self, service, start_history_id, limit):
        changed = []
        deleted = set()
        page_token = None
        cursor = start_history_id
        complete = False
        while len(changed) < limit and not complete:
            page = service.users().history().list(
                userId="me", startHistoryId=start_history_id,
                maxResults=100, pageToken=page_token,
            ).execute()
            for history in page.get("history", []):
                record_ids = []
                for field in ("messagesAdded", "labelsAdded", "labelsRemoved"):
                    record_ids.extend(
                        event["message"]["id"] for event in history.get(field, [])
                    )
                record_deleted = {
                    event["message"]["id"]
                    for event in history.get("messagesDeleted", [])
                }
                new_ids = [identifier for identifier in record_ids if identifier not in changed]
                if len(new_ids) > limit and not changed:
                    raise GmailSyncError(
                        "Gmail returned too many changes at once. Reconnect to start a bounded full sync."
                    )
                if len(changed) + len(new_ids) > limit:
                    complete = True
                    break
                changed.extend(new_ids)
                deleted.update(record_deleted)
                cursor = history.get("id", cursor)
            if complete:
                break
            page_token = page.get("nextPageToken")
            if not page_token:
                cursor = page.get("historyId", cursor)
                complete = True

        messages = []
        removed = set(deleted)
        for identifier in changed:
            if identifier in deleted:
                continue
            try:
                messages.append(self._get(service, identifier))
            except HttpError as error:
                if getattr(error.resp, "status", None) != 404:
                    raise
                removed.add(identifier)
        return GmailBatch(messages, cursor, "incremental", tuple(sorted(removed)))

    def _get(self, service, identifier):
        raw = service.users().messages().get(
            userId="me", id=identifier, format="full"
        ).execute()
        return normalize_gmail_message(raw)

    def _service(self, refresh_token):
        if not self.client_id or not self.client_secret:
            raise GmailSyncError("Gmail OAuth is not configured.")
        credentials = Credentials(
            token=None,
            refresh_token=refresh_token,
            token_uri="https://oauth2.googleapis.com/token",
            client_id=self.client_id,
            client_secret=self.client_secret,
            scopes=[GMAIL_READONLY_SCOPE],
        )
        return build("gmail", "v1", credentials=credentials, cache_discovery=False)


def get_gmail_mail_provider():
    provider = current_app.config.get("GMAIL_MAIL_PROVIDER")
    if provider is not None:
        return provider
    return GmailMailProvider(
        current_app.config["GMAIL_CLIENT_ID"],
        current_app.config["GMAIL_CLIENT_SECRET"],
    )
