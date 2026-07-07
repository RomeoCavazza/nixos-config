{
  config,
  lib,
  locality,
  pkgs,
  ...
}:
let
  inherit (locality) user;
  homeDir = config.users.users.${user}.home;
  repository = "s3:s3.eu-central-003.backblazeb2.com/tco-nixos-backup/restic";
  passwordFile = config.sops.secrets.restic_password.path;
  environmentFile = config.sops.templates."restic-b2.env".path;

  resticRestoreDrill = pkgs.writeShellApplication {
    name = "restic-restore-drill";
    runtimeInputs = [
      pkgs.restic
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      export RESTIC_REPOSITORY="${repository}"
      export RESTIC_PASSWORD_FILE="${passwordFile}"
      while IFS='=' read -r __k __v || [[ -n "$__k" ]]; do
        [[ "$__k" == AWS_* ]] && export "$__k=$__v"
      done < "${environmentFile}"

      failures=0
      warnings=0
      ok() { printf '[ok] %s\n' "$*"; }
      warn() { printf '[warn] %s\n' "$*"; warnings=$((warnings + 1)); }
      fail() { printf '[fail] %s\n' "$*"; failures=$((failures + 1)); }

      if [[ $EUID -ne 0 ]]; then
        printf '[fail] must run as root (use: sudo restic-restore-drill)\n' >&2
        exit 1
      fi

      restic_probe_log="$(mktemp)"
      if restic snapshots --tag critical --latest 1 > /dev/null 2>"$restic_probe_log"; then
        ok "repository reachable and credentials valid"
      else
        printf '[fail] cannot reach repository or list snapshots\n' >&2
        sed -n '1,12p' "$restic_probe_log" >&2
        exit 1
      fi

      snap_time="$(restic snapshots --tag critical --latest 1 --json 2>/dev/null | jq -r '.[0].time // empty')"
      if [[ -n "$snap_time" ]]; then
        age_days=$(( ( $(date +%s) - $(date -d "$snap_time" +%s) ) / 86400 ))
        if (( age_days <= 2 )); then
          ok "latest critical snapshot is fresh (''${age_days}d old)"
        else
          warn "latest critical snapshot is ''${age_days}d old (backup timer may be failing)"
        fi
      else
        warn "could not determine latest snapshot age"
      fi

      if restic check >/dev/null 2>&1; then
        ok "restic check passed (structure intact)"
      else
        fail "restic check failed (integrity problem)"
      fi

      canary="${locality.activeConfigRepo}/flake.nix"
      target="$(mktemp -d)"
      trap 'rm -rf "$target"' EXIT
      if restic restore latest --tag critical --target "$target" --include "$canary" >/dev/null 2>&1 && [[ -s "$target$canary" ]]; then
        ok "canary restore succeeded ($canary)"
      else
        fail "canary restore failed ($canary not recovered)"
      fi

      if (( failures > 0 )); then
        printf 'restic-restore-drill: %s failure(s), %s warning(s)\n' "$failures" "$warnings" >&2
        exit 1
      fi
      if (( warnings > 0 )); then
        printf 'restic-restore-drill: passed with %s warning(s)\n' "$warnings"
      else
        ok "restore drill passed — b2-critical backup is restorable"
      fi
    '';
  };
in
{
  sops.secrets.restic_password = { };
  sops.secrets.b2_key_id = { };
  sops.secrets.b2_app_key = { };

  sops.templates."restic-b2.env" = {
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.b2_key_id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.b2_app_key}
    '';
  };

  environment.systemPackages = [
    pkgs.restic
    resticRestoreDrill
  ];

  system.build.resticRestoreDrill = resticRestoreDrill;

  services.restic.backups = {
    b2-critical = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        locality.activeConfigRepo
        "${homeDir}/.ssh"
        "${homeDir}/.gnupg"
      ];

      exclude = [
        "**/__pycache__"
        "**/.DS_Store"
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
        "${homeDir}/Bureau"
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

    b2-gitlab = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      backupPrepareCommand = ''
        ${pkgs.sudo}/bin/sudo -u gitlab \
          ${pkgs.postgresql}/bin/pg_dump \
            --no-password \
            gitlabhq_production \
          > /var/lib/gitlab/db-dump.sql
        chmod 600 /var/lib/gitlab/db-dump.sql
      '';

      paths = [
        "/var/lib/gitlab/repositories"
        "/var/lib/gitlab/uploads"
        "/var/lib/gitlab/shared"
        "/var/lib/gitlab/db-dump.sql"
      ];

      exclude = [
        "/var/lib/gitlab/shared/cache"
        "/var/lib/gitlab/tmp"
      ];

      extraBackupArgs = [
        "--tag"
        "gitlab"
      ];

      timerConfig = {
        OnCalendar = "04:00";
        Persistent = true;
        RandomizedDelaySec = "15min";
      };

      pruneOpts = [
        "--tag"
        "gitlab"
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

    b2-sigma-rag = {
      inherit environmentFile passwordFile repository;
      initialize = true;

      paths = [
        "${homeDir}/Bureau/projets/rag/data/raw"
        "${homeDir}/Bureau/projets/rag/data/external"
      ];

      extraBackupArgs = [
        "--tag"
        "sigma-rag"
      ];

      timerConfig = {
        OnCalendar = "03:30";
        Persistent = true;
        RandomizedDelaySec = "15min";
      };

      pruneOpts = [
        "--tag"
        "sigma-rag"
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

  systemd.services."restic-restore-drill" = {
    description = "Non-destructive Restic restore drill";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe resticRestoreDrill;
    };
  };

  systemd.timers."restic-restore-drill" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
