import os
from pathlib import Path


def load_local_environment():
    """Load the single-user development environment before Config is evaluated."""
    if os.environ.get("INBOX_ENV") == "production":
        return
    path = Path(__file__).resolve().parent.parent / "instance" / "inbox.env"
    if not path.is_file():
        return
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key.startswith("INBOX_") or key in {
            "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GMAIL_CLIENT_ID",
            "GMAIL_CLIENT_SECRET", "GMAIL_REDIRECT_URI",
        }:
            os.environ[key] = value.strip()


load_local_environment()


class Config:
    ENVIRONMENT = os.environ.get("INBOX_ENV", "development")
    SECRET_KEY = os.environ.get("INBOX_SECRET", "dev-change-me")
    DATABASE = os.environ.get("INBOX_DATABASE")
    ASSISTANT_PROVIDER = os.environ.get("INBOX_ASSISTANT", "demo")
    OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
    OPENAI_MODEL = os.environ.get("INBOX_OPENAI_MODEL", "gpt-5.6-luna")
    OPENAI_TIMEOUT = float(os.environ.get("INBOX_OPENAI_TIMEOUT", "20"))
    ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")
    ANTHROPIC_MODEL = os.environ.get(
        "INBOX_ANTHROPIC_MODEL", "claude-haiku-4-5-20251001"
    )
    ANTHROPIC_TIMEOUT = float(os.environ.get("INBOX_ANTHROPIC_TIMEOUT", "20"))
    MAIL_PROVIDER = os.environ.get("INBOX_MAIL_PROVIDER", "json")
    CSRF_ENABLED = os.environ.get("INBOX_CSRF", "1") == "1"
    SECURE_COOKIES = os.environ.get("INBOX_SECURE_COOKIES", "1") == "1"
    MAX_CONTENT_LENGTH = int(os.environ.get("INBOX_MAX_UPLOAD", str(2 * 1024 * 1024)))
    GMAIL_CLIENT_ID = os.environ.get("GMAIL_CLIENT_ID")
    GMAIL_CLIENT_SECRET = os.environ.get("GMAIL_CLIENT_SECRET")
    GMAIL_REDIRECT_URI = os.environ.get(
        "GMAIL_REDIRECT_URI", "http://127.0.0.1:8000/oauth/gmail/callback"
    )


def configure_app(app, overrides=None):
    app.config.from_object(Config)
    if not app.config["DATABASE"]:
        app.config["DATABASE"] = os.path.join(app.instance_path, "inbox.sqlite3")
    if overrides:
        app.config.update(overrides)
    if app.config["ENVIRONMENT"] == "production" and app.config["SECRET_KEY"] == "dev-change-me":
        raise RuntimeError("INBOX_SECRET must be set in production")
    if app.config["ENVIRONMENT"] == "production":
        app.config.update(
            SESSION_COOKIE_HTTPONLY=True,
            SESSION_COOKIE_SAMESITE="Lax",
            SESSION_COOKIE_SECURE=app.config["SECURE_COOKIES"],
        )
