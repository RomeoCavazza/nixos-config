import hmac
import sqlite3

from flask import Blueprint, current_app, flash, redirect, request, session, url_for

from ..gmail_mail import GmailSyncError, get_gmail_mail_provider
from ..gmail_oauth import GmailConfigurationError, GmailOAuthError, get_gmail_oauth
from ..repositories import (
    ConnectedAccountRepository, EmailRepository, RuleRepository, SyncRunRepository,
)
from ..services import classify_email
from . import login_required

bp = Blueprint("gmail", __name__, url_prefix="/oauth/gmail")


@bp.post("/connect")
@login_required
def connect():
    try:
        authorization_url, state, code_verifier = get_gmail_oauth().authorization_url()
    except GmailConfigurationError as error:
        flash(str(error), "error")
        return redirect(url_for("settings.settings_page") + "#gmail")
    session["gmail_oauth_state"] = state
    session["gmail_oauth_code_verifier"] = code_verifier
    return redirect(authorization_url)


@bp.get("/callback")
@login_required
def callback():
    if request.args.get("error"):
        session.pop("gmail_oauth_state", None)
        session.pop("gmail_oauth_code_verifier", None)
        flash("Gmail connection was cancelled.", "error")
        return redirect(url_for("settings.settings_page") + "#gmail")

    expected = session.pop("gmail_oauth_state", None)
    code_verifier = session.pop("gmail_oauth_code_verifier", None)
    received = request.args.get("state", "")
    if not expected or not code_verifier or not hmac.compare_digest(expected, received):
        return "Invalid OAuth state", 400

    try:
        account = get_gmail_oauth().exchange(request.url, expected, code_verifier)
    except (GmailConfigurationError, GmailOAuthError, ValueError) as error:
        current_app.logger.warning("Gmail OAuth failed: %s", error)
        flash(str(error), "error")
    else:
        ConnectedAccountRepository().upsert(
            session["user_id"], "gmail", account["email"],
            account["refresh_token"], account["scopes"],
        )
        flash("Gmail connected.", "success")
    return redirect(url_for("settings.settings_page") + "#gmail")


@bp.post("/disconnect")
@login_required
def disconnect():
    ConnectedAccountRepository().delete(session["user_id"], "gmail")
    flash("Gmail disconnected.", "success")
    return redirect(url_for("settings.settings_page") + "#gmail")


@bp.post("/sync")
@login_required
def sync():
    user_id = session["user_id"]
    accounts = ConnectedAccountRepository()
    account = accounts.find(user_id, "gmail")
    if account is None:
        flash("Connect Gmail first.", "error")
        return redirect(url_for("settings.settings_page") + "#gmail")

    runs = SyncRunRepository()
    mode = "incremental" if account["history_id"] else "full"
    try:
        run_id = runs.start(user_id, account["id"], mode)
    except sqlite3.IntegrityError:
        flash("A Gmail sync is already running.", "error")
        return redirect(url_for("settings.settings_page") + "#gmail")
    try:
        batch = get_gmail_mail_provider().sync(account, limit=25)
        runs.set_mode(run_id, batch.mode)
        if batch.mode == "full":
            EmailRepository().prepare_full_gmail_sync(user_id, account["id"])
        imported, updated = EmailRepository().upsert_gmail_many(
            user_id, account["id"], batch.messages,
            RuleRepository().list(user_id), classify_email,
        )
        updated += EmailRepository().mark_gmail_removed(
            user_id, account["id"], batch.removed_ids
        )
        accounts.record_sync(user_id, account["id"], batch.history_id)
        runs.complete(run_id, imported, updated)
    except (GmailSyncError, sqlite3.Error) as error:
        current_app.logger.warning("Gmail sync failed: %s", error)
        runs.fail(run_id, str(error))
        message = str(error) if isinstance(error, GmailSyncError) else "Local Gmail sync failed."
        flash(message, "error")
    else:
        flash(f"Gmail synced: {imported} new, {updated} updated.", "success")
    return redirect(url_for("settings.settings_page") + "#gmail")
