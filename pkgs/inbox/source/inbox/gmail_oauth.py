import os
from contextlib import contextmanager
from urllib.parse import urlparse

from flask import current_app
from google.auth.exceptions import GoogleAuthError
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from oauthlib.oauth2 import OAuth2Error

GMAIL_READONLY_SCOPE = "https://www.googleapis.com/auth/gmail.readonly"


class GmailConfigurationError(RuntimeError):
    pass


class GmailOAuthError(RuntimeError):
    pass


class GmailOAuth:
    def __init__(self, client_id, client_secret, redirect_uri):
        if not client_id or not client_secret or not redirect_uri:
            raise GmailConfigurationError("Gmail OAuth is not configured.")
        self.client_config = {
            "web": {
                "client_id": client_id,
                "client_secret": client_secret,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [redirect_uri],
            }
        }
        self.redirect_uri = redirect_uri

    def authorization_url(self):
        flow = self._flow()
        authorization_url, state = flow.authorization_url(
            access_type="offline",
            include_granted_scopes="true",
            prompt="consent",
        )
        return authorization_url, state, flow.code_verifier

    def exchange(self, authorization_response, state, code_verifier):
        flow = self._flow(state=state, code_verifier=code_verifier)
        try:
            with self._allow_local_http():
                flow.fetch_token(authorization_response=authorization_response)
            credentials = flow.credentials
        except (GoogleAuthError, OAuth2Error, ValueError) as error:
            error_code = getattr(error, "error", type(error).__name__)
            raise GmailOAuthError(
                f"Google token exchange failed ({error_code})."
            ) from error
        if not credentials.refresh_token:
            raise GmailConfigurationError("Google did not return a refresh token.")
        try:
            profile = build(
                "gmail", "v1", credentials=credentials, cache_discovery=False
            ).users().getProfile(userId="me").execute()
        except (GoogleAuthError, HttpError) as error:
            raise GmailOAuthError("Gmail could not read the account profile.") from error
        return {
            "email": profile["emailAddress"],
            "refresh_token": credentials.refresh_token,
            "scopes": " ".join(credentials.scopes or [GMAIL_READONLY_SCOPE]),
        }

    def _flow(self, state=None, code_verifier=None):
        flow = Flow.from_client_config(
            self.client_config,
            scopes=[GMAIL_READONLY_SCOPE],
            state=state,
            code_verifier=code_verifier,
            autogenerate_code_verifier=code_verifier is None,
        )
        flow.redirect_uri = self.redirect_uri
        return flow

    @contextmanager
    def _allow_local_http(self):
        redirect = urlparse(self.redirect_uri)
        is_loopback = redirect.scheme == "http" and redirect.hostname in {
            "127.0.0.1", "localhost"
        }
        previous = os.environ.get("OAUTHLIB_INSECURE_TRANSPORT")
        if is_loopback:
            os.environ["OAUTHLIB_INSECURE_TRANSPORT"] = "1"
        try:
            yield
        finally:
            if is_loopback:
                if previous is None:
                    os.environ.pop("OAUTHLIB_INSECURE_TRANSPORT", None)
                else:
                    os.environ["OAUTHLIB_INSECURE_TRANSPORT"] = previous


def get_gmail_oauth():
    service = current_app.config.get("GMAIL_OAUTH_SERVICE")
    if service is not None:
        return service
    return GmailOAuth(
        current_app.config["GMAIL_CLIENT_ID"],
        current_app.config["GMAIL_CLIENT_SECRET"],
        current_app.config["GMAIL_REDIRECT_URI"],
    )
