from flask import Blueprint, redirect, render_template, request, session, url_for

from ..repositories import AssistantRepository, EmailRepository
from . import login_required, mailbox_counts

bp = Blueprint("mailbox", __name__)


@bp.get("/dashboard")
@login_required
def dashboard():
    view = request.args.get("view", "inbox")
    query = request.args.get("q", "").strip()
    emails = EmailRepository().list(session["user_id"], view, query)
    return render_template(
        "dashboard.html",
        emails=emails,
        counts=mailbox_counts(),
        view=view,
        query=query,
        active_page=view,
    )


@bp.get("/emails/<int:email_id>")
@login_required
def email_detail(email_id):
    repository = EmailRepository()
    email = repository.find_owned(session["user_id"], email_id)
    if email is None:
        return "Message not found", 404
    results = AssistantRepository().for_email(session["user_id"], email_id)
    return render_template(
        "email.html", email=email, thread=repository.thread(session["user_id"], email_id),
        results=results, counts=mailbox_counts(),
    )


@bp.post("/emails/<int:email_id>/<action>")
@login_required
def email_action(email_id, action):
    repository = EmailRepository()
    if action not in repository.ACTIONS:
        return "Unknown action", 400
    repository.toggle(session["user_id"], email_id, action)
    return redirect(request.referrer or url_for("mailbox.dashboard"))
