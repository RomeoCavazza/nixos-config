"""Store local development credentials without echoing secrets or tracking them."""

import getpass
import os
from pathlib import Path


PATH = Path(__file__).with_name("instance") / "inbox.env"


def ask(label, key, secret=False):
    existing = os.environ.get(key, "")
    prompt = f"{label}{' [keep current]' if existing else ''}: "
    value = getpass.getpass(prompt) if secret else input(prompt)
    return value.strip() or existing


def main():
    values = {
        "INBOX_ASSISTANT": "anthropic",
        "ANTHROPIC_API_KEY": ask("Anthropic API key", "ANTHROPIC_API_KEY", True),
        "GMAIL_CLIENT_ID": ask("Google Client ID", "GMAIL_CLIENT_ID"),
        "GMAIL_CLIENT_SECRET": ask("Google Client Secret", "GMAIL_CLIENT_SECRET", True),
        "GMAIL_REDIRECT_URI": "http://127.0.0.1:8000/oauth/gmail/callback",
    }
    missing = [key for key, value in values.items() if not value]
    if missing:
        raise SystemExit("Missing: " + ", ".join(missing))
    PATH.parent.mkdir(parents=True, exist_ok=True)
    PATH.write_text("".join(f"{key}={value}\n" for key, value in values.items()))
    PATH.chmod(0o600)
    print(f"Saved {PATH} with mode 0600.")


if __name__ == "__main__":
    main()
