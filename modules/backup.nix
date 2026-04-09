{ config, pkgs, ... }:
let
  repository = "s3:s3.eu-central-003.backblazeb2.com/tco-nixos-backup/restic";
  passwordFile = config.sops.secrets.restic_password.path;
  environmentFile = config.sops.templates."restic-b2.env".path;
in
{
  sops.defaultSopsFile = ../secrets/backup.yaml;
  sops.age.sshKeyPaths = [ "/home/tco/.ssh/id_ed25519" ];

  sops.secrets.restic_password = {};
  sops.secrets.b2_key_id = {};
  sops.secrets.b2_app_key = {};

  sops.templates."restic-b2.env" = {
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.b2_key_id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.b2_app_key}
    '';
  };

  environment.systemPackages = [ pkgs.restic ];

  services.restic.backups = {
    b2-critical = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        "/etc/nixos"
        "/home/tco/.ssh"
        "/home/tco/.gnupg"
        "/home/tco/.config"
      ];

      exclude = [
        "/home/tco/.config/Cursor/Cache"
        "/home/tco/.config/google-chrome/Default/Cache"
        "/home/tco/.config/chromium/Default/Cache"
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

    b2-data = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        "/home/tco/Desktop"
        "/home/tco/Documents"
        "/home/tco/Images"
      ];

      exclude = [
        "/home/tco/Downloads"
        "/home/tco/Telechargements"
        "/home/tco/Téléchargements"
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
