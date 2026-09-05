{ ... }:
{
  imports = [ ./inbox.nix ];

  services.inbox = {
    enable = true;
    source = /path/to/inbox;
    credentials = {
      inboxSecret = /run/secrets/inbox-secret;
      anthropicApiKey = /run/secrets/anthropic-api-key;
      gmailClientId = /run/secrets/gmail-client-id;
      gmailClientSecret = /run/secrets/gmail-client-secret;
    };
  };
}
