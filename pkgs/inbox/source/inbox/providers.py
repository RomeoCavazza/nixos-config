from typing import Protocol

from flask import current_app

from .anthropic_assistant import AnthropicAssistant
from .assistant import DemoAssistant, PriorityResult
from .openai_assistant import OpenAIAssistant
from .services import normalize_import


class AssistantProvider(Protocol):
    name: str

    def analyze_priority(self, email) -> PriorityResult: ...
    def summarize(self, email) -> str: ...
    def suggest_reply(self, email, user_name: str) -> str: ...


class MailProvider(Protocol):
    name: str

    def normalize(self, payload) -> list[dict]: ...


class JsonMailProvider:
    name = "json"

    def normalize(self, payload):
        return normalize_import(payload)


def get_assistant_provider() -> AssistantProvider:
    provider = current_app.config["ASSISTANT_PROVIDER"]
    if not isinstance(provider, str):
        return provider
    if provider == "demo":
        return DemoAssistant()
    if provider == "openai":
        return OpenAIAssistant(
            api_key=current_app.config["OPENAI_API_KEY"],
            model=current_app.config["OPENAI_MODEL"],
            timeout=current_app.config["OPENAI_TIMEOUT"],
        )
    if provider == "anthropic":
        return AnthropicAssistant(
            api_key=current_app.config["ANTHROPIC_API_KEY"],
            model=current_app.config["ANTHROPIC_MODEL"],
            timeout=current_app.config["ANTHROPIC_TIMEOUT"],
        )
    raise RuntimeError(f"Unknown assistant provider: {provider}")


def get_mail_provider() -> MailProvider:
    provider = current_app.config["MAIL_PROVIDER"]
    if not isinstance(provider, str):
        return provider
    if provider == "json":
        return JsonMailProvider()
    raise RuntimeError(f"Unknown mail provider: {provider}")
