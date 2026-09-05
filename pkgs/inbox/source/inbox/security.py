import hmac
import secrets

from flask import abort, request, session


def csrf_token():
    token = session.get("csrf_token")
    if token is None:
        token = secrets.token_urlsafe(32)
        session["csrf_token"] = token
    return token


def init_app(app):
    app.jinja_env.globals["csrf_token"] = csrf_token

    @app.before_request
    def protect_post_requests():
        if request.method != "POST" or app.config["TESTING"] or not app.config["CSRF_ENABLED"]:
            return None
        expected = session.get("csrf_token", "")
        received = request.form.get("csrf_token", "") or request.headers.get("X-CSRF-Token", "")
        if not expected or not received or not hmac.compare_digest(expected, received):
            abort(400, "Invalid CSRF token")
        return None
