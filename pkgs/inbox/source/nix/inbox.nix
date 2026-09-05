{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.inbox;
  python = pkgs.python3.withPackages (
    ps: with ps; [
      flask
      anthropic
      google-api-python-client
      google-auth-oauthlib
      openai
      gunicorn
    ]
  );
  start = pkgs.writeShellScript "inbox-start" ''
    set -eu
    read_secret() { tr -d '\n' < "$CREDENTIALS_DIRECTORY/$1"; }
    export INBOX_SECRET="$(read_secret inbox-secret)"
    export ANTHROPIC_API_KEY="$(read_secret anthropic-api-key)"
    export GMAIL_CLIENT_ID="$(read_secret gmail-client-id)"
    export GMAIL_CLIENT_SECRET="$(read_secret gmail-client-secret)"
    exec ${python}/bin/gunicorn --workers 2 --bind 127.0.0.1:${toString cfg.port} run:app
  '';
in
{
  options.services.inbox = {
    enable = lib.mkEnableOption "Inbox email triage";
    source = lib.mkOption {
      type = lib.types.path;
      description = "Inbox source directory copied to the Nix store.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };
    credentials = {
      inboxSecret = lib.mkOption { type = lib.types.path; };
      anthropicApiKey = lib.mkOption { type = lib.types.path; };
      gmailClientId = lib.mkOption { type = lib.types.path; };
      gmailClientSecret = lib.mkOption { type = lib.types.path; };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.inbox = {
      description = "Inbox";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        INBOX_ENV = "production";
        INBOX_ASSISTANT = "anthropic";
        INBOX_DATABASE = "/var/lib/inbox/inbox.sqlite3";
        INBOX_SECURE_COOKIES = "0";
        GMAIL_REDIRECT_URI = "http://127.0.0.1:${toString cfg.port}/oauth/gmail/callback";
        PYTHONPATH = toString cfg.source;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = start;
        WorkingDirectory = cfg.source;
        DynamicUser = true;
        StateDirectory = "inbox";
        StateDirectoryMode = "0700";
        LoadCredential = [
          "inbox-secret:${cfg.credentials.inboxSecret}"
          "anthropic-api-key:${cfg.credentials.anthropicApiKey}"
          "gmail-client-id:${cfg.credentials.gmailClientId}"
          "gmail-client-secret:${cfg.credentials.gmailClientSecret}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        LockPersonality = true;
      };
    };
  };
}
