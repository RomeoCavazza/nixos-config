from .provider_errors import AssistantProviderError


def email_input(email):
    return (
        f"From: {email['sender_name']} <{email['sender_email']}>\n"
        f"Subject: {email['subject']}\n\n{email['body'] or email['snippet']}"
    )


def bounded_text(value, maximum, provider):
    value = str(value).strip()
    if not value or len(value) > maximum:
        raise AssistantProviderError(
            f"{provider} returned content with an invalid length."
        )
    return value
