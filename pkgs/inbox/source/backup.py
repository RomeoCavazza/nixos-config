"""Create a consistent SQLite backup without stopping Inbox."""

import argparse
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "destination", nargs="?",
        default=f"inbox-{datetime.now(timezone.utc):%Y%m%d-%H%M%S}.sqlite3",
    )
    args = parser.parse_args()
    source = Path(os.environ.get("INBOX_DATABASE", Path(__file__).parent / "instance" / "inbox.sqlite3"))
    destination = Path(args.destination).resolve()
    if destination == source.resolve():
        raise SystemExit("Backup destination must differ from the live database.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(source) as live, sqlite3.connect(destination) as backup:
        live.backup(backup)
    destination.chmod(0o600)
    print(destination)


if __name__ == "__main__":
    main()
