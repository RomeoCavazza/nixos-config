from flask import Blueprint, flash, jsonify, redirect, render_template, request, session, url_for

from ..provider_errors import AssistantProviderError
from ..providers import get_assistant_provider
from ..repositories import AssistantRepository, EmailRepository
from . import login_required, mailbox_counts

bp = Blueprint("assistant", __name__)


@bp.get("/priorities")
@login_required
def priorities():
    repository = AssistantRepository()
    return render_template(
        "priorities.html",
        results=repository.priorities(session["user_id"]),
        last_run=repository.last_priorities_run(session["user_id"]),
        counts=mailbox_counts(),
        active_page="priorities",
    )


@bp.post("/priorities/analyze")
@login_required
def analyze_priorities():
    try:
        provider = get_assistant_provider()
        repository = AssistantRepository()
        emails = EmailRepository().active(session["user_id"])
        if hasattr(provider, "analyze_priorities"):
            results = provider.analyze_priorities(emails)
        else:
            results = {
                email["id"]: provider.analyze_priority(email) for email in emails
            }
        for email in emails:
            result = results[email["id"]]
            repository.save(
                session["user_id"], email["id"], "priority", result.action,
                provider.name, result.reason, result.score,
            )
        repository.record_priorities_run(session["user_id"], provider.name)
    except AssistantProviderError as error:
        flash(str(error), "error")
    return redirect(url_for("assistant.priorities"))


def _owned_email(email_id):
    repository = EmailRepository()
    email = repository.find_owned(session["user_id"], email_id)
    if email is None:
        return None
    payload = dict(email)
    thread = repository.thread(session["user_id"], email_id)
    if len(thread) > 1:
        payload["body"] = "\n\n".join(
            f"From: {item['sender_name']} <{item['sender_email']}>\n"
            f"Date: {item['received_at']}\n\n{item['body'] or item['snippet']}"
            for item in thread
        )
    return payload


def _wants_json():
    return request.accept_mimetypes.best == "application/json"


@bp.post("/emails/<int:email_id>/summarize")
@login_required
def summarize_email(email_id):
    email = _owned_email(email_id)
    if email is None:
        return "Message not found", 404
    try:
        provider = get_assistant_provider()
        summary = provider.summarize(email)
        AssistantRepository().save(
            session["user_id"], email_id, "summary", summary, provider.name
        )
    except AssistantProviderError as error:
        if _wants_json():
            return jsonify(error=str(error)), 502
        flash(str(error), "error")
    else:
        if _wants_json():
            return jsonify(content=summary, provider=provider.name)
    return redirect(url_for("mailbox.email_detail", email_id=email_id) + "#summary")


@bp.post("/emails/<int:email_id>/suggest-reply")
@login_required
def suggest_reply(email_id):
    email = _owned_email(email_id)
    if email is None:
        return "Message not found", 404
    try:
        provider = get_assistant_provider()
        reply = provider.suggest_reply(email, session["name"])
        AssistantRepository().save(
            session["user_id"], email_id, "reply", reply, provider.name
        )
    except AssistantProviderError as error:
        if _wants_json():
            return jsonify(error=str(error)), 502
        flash(str(error), "error")
    else:
        if _wants_json():
            return jsonify(content=reply, provider=provider.name)
    return redirect(url_for("mailbox.email_detail", email_id=email_id) + "#reply")
