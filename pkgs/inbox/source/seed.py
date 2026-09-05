import json
from pathlib import Path

from werkzeug.security import generate_password_hash

from inbox import create_app
from inbox.database import get_db, init_db
from inbox.providers import JsonMailProvider
from inbox.repositories import EmailRepository, RuleRepository, UserRepository
from inbox.services import classify_email

app = create_app()
with app.app_context():
    db = get_db()
    db.executescript("""
        DROP TABLE IF EXISTS sync_runs;
        DROP TABLE IF EXISTS assistant_runs;
        DROP TABLE IF EXISTS assistant_results;
        DROP TABLE IF EXISTS rules;
        DROP TABLE IF EXISTS emails;
        DROP TABLE IF EXISTS connected_accounts;
        DROP TABLE IF EXISTS users;
        DROP TABLE IF EXISTS schema_migrations;
    """)
    init_db()
    user_id = UserRepository().create(
        "Demo User", "user@example.com", generate_password_hash("sudo")
    )
    rules = RuleRepository()
    rules.add(user_id, "sender", "newsletter", "archive")
    payload = json.loads((Path(__file__).parent / "data/demo-emails.json").read_text())
    emails = JsonMailProvider().normalize(payload)
    EmailRepository().import_many(user_id, emails, rules.list(user_id), classify_email)
    print("Inbox demo ready: user@example.com / sudo")
