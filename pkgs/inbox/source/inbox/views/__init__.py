from functools import wraps

from flask import redirect, session, url_for

from ..repositories import EmailRepository


def login_required(view):
    @wraps(view)
    def wrapped(**kwargs):
        if not session.get("user_id"):
            return redirect(url_for("auth.login"))
        return view(**kwargs)

    return wrapped


def mailbox_counts():
    return EmailRepository().counts(session["user_id"])
