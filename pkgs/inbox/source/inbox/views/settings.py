import json

from flask import Blueprint, flash, redirect, render_template, request, session, url_for

from ..providers import get_mail_provider
from ..repositories import ConnectedAccountRepository, EmailRepository, RuleRepository
from ..services import classify_email
from . import login_required, mailbox_counts

bp = Blueprint("settings", __name__)


@bp.get("/settings")
@login_required
def settings_page():
    gmail_account = ConnectedAccountRepository().find(session["user_id"], "gmail")
    return render_template(
        "settings.html",
        rules=RuleRepository().list(session["user_id"]),
        counts=mailbox_counts(),
        active_page="settings",
        gmail_account=gmail_account,
    )


@bp.post("/rules")
@login_required
def add_rule():
    form = request.form
    field = form.get("field", "")
    action = form.get("action", "")
    value = form.get("value", "").strip()
    action_value = form.get("action_value", "").strip()
    if field not in {"sender", "subject"} or action not in {
        "prioritize", "archive", "category"
    } or not value:
        flash("Invalid rule.", "error")
        return redirect(url_for("settings.settings_page") + "#rules")
    if action == "prioritize" and action_value:
        try:
            score = int(action_value)
        except ValueError:
            score = -1
        if not 0 <= score <= 100:
            flash("Priority must be between 0 and 100.", "error")
            return redirect(url_for("settings.settings_page") + "#rules")
    RuleRepository().add(
        session["user_id"], field, value, action, action_value,
    )
    flash("Rule created.", "success")
    return redirect(url_for("settings.settings_page") + "#rules")


@bp.post("/rules/<int:rule_id>/delete")
@login_required
def delete_rule(rule_id):
    RuleRepository().delete(session["user_id"], rule_id)
    return redirect(url_for("settings.settings_page") + "#rules")


@bp.post("/import")
@login_required
def import_json():
    try:
        payload = json.load(request.files["file"])
        emails = get_mail_provider().normalize(payload)
        rules = RuleRepository().list(session["user_id"])
        count = EmailRepository().import_many(
            session["user_id"], emails, rules, classify_email
        )
        flash(f"Imported and analyzed {count} new messages.", "success")
    except (KeyError, ValueError, json.JSONDecodeError) as error:
        flash(str(error), "error")
    return redirect(url_for("settings.settings_page") + "#import")
