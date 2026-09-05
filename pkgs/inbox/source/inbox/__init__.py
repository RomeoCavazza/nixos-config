from flask import Flask

# AI assistance disclosure: OpenAI Codex assisted with design review,
# implementation, tests, and documentation. See README.md for the full scope.

from . import database
from . import security
from .config import configure_app


def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    configure_app(app, test_config)

    database.init_app(app)
    security.init_app(app)

    @app.get("/healthz")
    def health():
        return {"status": "ok"}

    @app.get("/readyz")
    def ready():
        database.get_db().execute("SELECT 1").fetchone()
        return {"status": "ready"}
    from .views.assistant import bp as assistant_bp
    from .views.auth import bp as auth_bp
    from .views.mailbox import bp as mailbox_bp
    from .views.gmail import bp as gmail_bp
    from .views.settings import bp as settings_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(mailbox_bp)
    app.register_blueprint(gmail_bp)
    app.register_blueprint(assistant_bp)
    app.register_blueprint(settings_bp)
    return app
