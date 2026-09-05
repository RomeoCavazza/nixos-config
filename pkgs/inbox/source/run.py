import os

from inbox import create_app

app = create_app()

if __name__ == "__main__":
    development = app.config["ENVIRONMENT"] != "production"
    app.run(
        host=os.environ.get("INBOX_HOST", "127.0.0.1"),
        port=int(os.environ.get("INBOX_PORT", "8000")),
        debug=os.environ.get("INBOX_DEBUG", "1" if development else "0") == "1",
    )
