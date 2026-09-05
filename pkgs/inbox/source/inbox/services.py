import re
from datetime import datetime


CATEGORY_KEYWORDS = {
    "Work": {"meeting", "project", "deadline", "review", "client", "équipe", "projet"},
    "Finance": {"invoice", "payment", "receipt", "bank", "facture", "paiement"},
    "Security": {"security", "password", "login", "alert", "sécurité", "connexion"},
    "Newsletter": {"newsletter", "digest", "weekly", "unsubscribe", "édition"},
    "Travel": {"flight", "hotel", "booking", "train", "voyage", "réservation"},
}

PRIORITY_WORDS = {
    "urgent": 35, "asap": 30, "deadline": 25, "action required": 30,
    "important": 20, "today": 15, "payment": 15, "security": 25,
    "réponse attendue": 25, "aujourd'hui": 15, "sécurité": 25,
}


def classify_email(email, rules=()):
    sender = f"{email.get('sender_name', '')} {email.get('sender_email', '')}".lower()
    text = f"{email.get('subject', '')} {email.get('snippet', '')} {email.get('body', '')}".lower()
    category, score, reasons = "Other", 20, []

    for candidate, words in CATEGORY_KEYWORDS.items():
        if any(word in text for word in words):
            category = candidate
            score += 10
            break
    for word, weight in PRIORITY_WORDS.items():
        if word in text:
            score += weight
            reasons.append(f'contains “{word}”')
    if "noreply" not in sender and "newsletter" not in text:
        score += 10

    archive = False
    for rule in rules:
        haystack = sender if rule["field"] == "sender" else text
        if rule["value"].lower() in haystack:
            if rule["action"] == "prioritize":
                score = max(score, int(rule["action_value"] or 90))
                reasons.append("matched a priority rule")
            elif rule["action"] == "archive":
                archive = True
            elif rule["action"] == "category":
                category = rule["action_value"] or category

    return {
        "category": category,
        "priority": min(score, 100),
        "reason": ", ".join(reasons[:2]) or "standard message",
        "is_archived": int(archive),
    }


def normalize_import(payload):
    items = payload.get("emails", payload) if isinstance(payload, dict) else payload
    if not isinstance(items, list):
        raise ValueError("JSON must be an array or contain an 'emails' array.")
    normalized = []
    for index, item in enumerate(items):
        sender = item.get("from") or item.get("sender_email") or "unknown@example.com"
        match = re.match(r"\s*(.*?)\s*<([^>]+)>\s*$", sender)
        normalized.append({
            "external_id": str(item.get("id") or f"import-{index}-{datetime.now().timestamp()}"),
            "sender_name": item.get("sender_name") or (match.group(1) if match else sender.split("@")[0]),
            "sender_email": match.group(2) if match else sender,
            "subject": item.get("subject") or "(no subject)",
            "snippet": item.get("snippet") or "",
            "body": item.get("body") or item.get("snippet") or "",
            "received_at": item.get("date") or item.get("received_at") or datetime.now().isoformat(timespec="seconds"),
        })
    return normalized
