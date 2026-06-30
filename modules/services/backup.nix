{ config, pkgs, ... }:
let
  user = "tco";
  homeDir = config.users.users.${user}.home;
  repoCheckout = "/etc/nixos";
  # Restic uses the B2 S3-compatible endpoint.
  repository = "s3:s3.eu-central-003.backblazeb2.com/tco-nixos-backup/restic";
  passwordFile = config.sops.secrets.restic_password.path;
  environmentFile = config.sops.templates."restic-b2.env".path;
in
{
  sops.secrets.restic_password = { };
  sops.secrets.b2_key_id = { };
  sops.secrets.b2_app_key = { };

  sops.templates."restic-b2.env" = {
    mode = "0400";
    content = ''
      # Rendered at activation time into /run/secrets/rendered/restic-b2.env
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.b2_key_id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.b2_app_key}
    '';
  };

  environment.systemPackages = [ pkgs.restic ];

  services.restic.backups = {
    # Critical machine state: config + credentials.
    b2-critical = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        repoCheckout
        "${homeDir}/.ssh"
        "${homeDir}/.gnupg"
        "${homeDir}/.config"
      ];

      exclude = [
        "${homeDir}/.config/Cursor/Cache"
        "${homeDir}/.config/google-chrome/Default/Cache"
        "${homeDir}/.config/chromium/Default/Cache"
        "**/__pycache__"
      ];

      extraBackupArgs = [
        "--tag"
        "critical"
      ];

      timerConfig = {
        OnCalendar = "02:00";
        Persistent = true;
        RandomizedDelaySec = "20min";
      };

      # Keep a longer history for machine recovery.
      pruneOpts = [
        "--tag"
        "critical"
        "--group-by"
        "tags,paths"
        "--keep-daily"
        "14"
        "--keep-weekly"
        "8"
        "--keep-monthly"
        "6"
      ];
    };

    # User data snapshots: lighter retention and separate schedule.
    b2-data = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        "${homeDir}/Desktop"
        "${homeDir}/Documents"
        "${homeDir}/Images"
      ];

      exclude = [
        "${homeDir}/Downloads"
        "**/node_modules"
        "**/target"
        "**/.direnv"
        "**/.venv"
        "**/__pycache__"
      ];

      extraBackupArgs = [
        "--tag"
        "data"
      ];

      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };

      pruneOpts = [
        "--tag"
        "data"
        "--group-by"
        "tags,paths"
        "--keep-daily"
        "7"
        "--keep-weekly"
        "4"
        "--keep-monthly"
        "3"
      ];
    };
  };
}
