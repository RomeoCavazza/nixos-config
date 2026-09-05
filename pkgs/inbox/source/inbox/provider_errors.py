class AssistantProviderError(RuntimeError):
    """Safe, user-facing failure from an external assistant provider."""


class AssistantConfigurationError(AssistantProviderError):
    pass
