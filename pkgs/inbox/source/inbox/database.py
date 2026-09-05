import sqlite3
import os
from pathlib import Path

import click
from flask import current_app, g


def get_db():
    if "db" not in g:
        database = Path(current_app.config["DATABASE"])
        database.parent.mkdir(parents=True, exist_ok=True)
        g.db = sqlite3.connect(database)
        os.chmod(database, 0o600)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


def close_db(_error=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = get_db()
    db.execute("""CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )""")
    db.commit()
    applied = {row["version"] for row in db.execute("SELECT version FROM schema_migrations")}
    migrations = Path(__file__).with_name("migrations")
    for migration in sorted(migrations.glob("*.sql")):
        if migration.name in applied:
            continue
        db.executescript(migration.read_text())
        db.execute("INSERT INTO schema_migrations(version) VALUES(?)", (migration.name,))
        db.commit()


@click.command("init-db")
def init_db_command():
    init_db()
    click.echo("Database initialized.")


def init_app(app):
    app.teardown_appcontext(close_db)
    app.cli.add_command(init_db_command)
    with app.app_context():
        init_db()
