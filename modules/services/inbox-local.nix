{ ... }:
{
  imports = [ ./inbox.nix ];
  services.inbox = {
    enable = true;
    source = builtins.path {
      path = ../../pkgs/inbox/source;
      name = "inbox-source";
    };
    credentials = {
      inboxSecret = "/run/secrets/inbox_secret";
      anthropicApiKey = "/run/secrets/inbox_anthropic_api_key";
      gmailClientId = "/run/secrets/inbox_gmail_client_id";
      gmailClientSecret = "/run/secrets/inbox_gmail_client_secret";
    };
  };
  sops.secrets = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = {
          sopsFile = ../../secrets/inbox.yaml;
        };
      })
      [
        "inbox_secret"
        "inbox_anthropic_api_key"
        "inbox_gmail_client_id"
        "inbox_gmail_client_secret"
      ]
  );
}
