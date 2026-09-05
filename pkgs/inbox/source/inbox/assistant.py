import re
from dataclasses import dataclass


@dataclass(frozen=True)
class PriorityResult:
    score: int
    action: str
    reason: str


class DemoAssistant:
    """Deterministic offline provider for demonstrations without an API key."""

    name = "demo"

    def analyze_priority(self, email):
        text = f"{email['subject']} {email['snippet']} {email['body']}".lower()
        score = int(email["priority"])
        deadline = re.search(r"\b(?:before|by|at)\s+([^.!?]+)", text)
        if any(word in text for word in ("action required", "urgent", "security", "deadline")):
            score = max(score, 80)
        action = self._action(email["subject"], email["snippet"])
        reason = "Direct action requested"
        if deadline:
            reason += f" with a deadline ({deadline.group(1).strip()})"
        elif score >= 70:
            reason += " and high-priority language"
        else:
            reason = "No immediate action detected"
        return PriorityResult(min(score, 100), action, reason)

    def summarize(self, email):
        source = (email["body"] or email["snippet"]).strip()
        sentences = [part.strip() for part in re.split(r"(?<=[.!?])\s+", source) if part.strip()]
        return " ".join(sentences[:2]) or "No content to summarize."

    def suggest_reply(self, email, user_name):
        first_name = email["sender_name"].split()[0]
        action = self._action(email["subject"], email["snippet"]).rstrip(".")
        return f"Hi {first_name},\n\nThanks for your message. I’ll {action.lower()}.\n\nBest,\n{user_name}"

    @staticmethod
    def _action(subject, snippet):
        text = f"{subject} {snippet}".lower()
        if "review" in text or "approve" in text:
            return "Review and respond to the request."
        if "security" in text:
            return "Review the security alert."
        if "payment" in text or "invoice" in text:
            return "Check the payment details."
        if "booking" in text or "train" in text:
            return "Check the booking details."
        return "Read the message and decide whether to respond."
