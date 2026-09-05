import sqlite3

from flask import Blueprint, flash, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

from ..repositories import UserRepository

bp = Blueprint("auth", __name__)


@bp.get("/")
def index():
    endpoint = "mailbox.dashboard" if session.get("user_id") else "auth.login"
    return redirect(url_for(endpoint))


@bp.route("/register", methods=("GET", "POST"))
def register():
    if request.method == "POST":
        name = request.form["name"].strip()
        email = request.form["email"].strip().lower()
        password = request.form["password"]
        error = "Please complete every field." if not name or not email or not password else None
        if not error and len(password) < 4:
            error = "Password must contain at least 4 characters."
        if not error:
            try:
                UserRepository().create(name, email, generate_password_hash(password))
            except sqlite3.IntegrityError:
                error = "An account already uses this email."
            else:
                flash("Account created. You can now sign in.", "success")
                return redirect(url_for("auth.login"))
        flash(error, "error")
    return render_template("auth.html", mode="register")


@bp.route("/login", methods=("GET", "POST"))
def login():
    if request.method == "POST":
        user = UserRepository().find_by_email(request.form["email"].strip().lower())
        if user and check_password_hash(user["password_hash"], request.form["password"]):
            session.clear()
            session["user_id"] = user["id"]
            session["name"] = user["name"]
            return redirect(url_for("mailbox.dashboard"))
        flash("Invalid email or password.", "error")
    return render_template("auth.html", mode="login")


@bp.post("/logout")
def logout():
    session.clear()
    return redirect(url_for("auth.login"))
