{
  config,
  locality,
  pkgs,
  ...
}:

let
  repoRoot = ../../.;
  inherit (locality) user;
  homeDir = config.users.users.${user}.home;
  stateDir = "/var/lib/grafana-snapshot-sync";

  snapshotScript = pkgs.writeShellApplication {
    name = "grafana-snapshot-sync";
    runtimeInputs = [
      pkgs.curl
      pkgs.git
      pkgs.nodejs
      pkgs.openssh
      pkgs.imagemagick
      pkgs.coreutils
      pkgs.gawk
      pkgs.google-chrome
      pkgs.playwright-driver
    ];
    text =
      let
        raw = builtins.readFile (repoRoot + "/config/bin/grafana-snapshot-sync");
        lines = pkgs.lib.splitString "\n" raw;
        body = pkgs.lib.concatStringsSep "\n" (pkgs.lib.tail lines);
      in
      ''
        export PLAYWRIGHT_CORE_PATH=${pkgs.playwright-driver}
      ''
      + body;
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 ${user} users -"
    "d ${stateDir}/snapshots 0755 ${user} users -"
  ];

  systemd.services.grafana-snapshot-sync = {
    description = "Render Grafana dashboards and sync changed PNGs to git";
    after = [
      "grafana.service"
      "nginx.service"
      "network-online.target"
    ];
    wants = [
      "nginx.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      WorkingDirectory = stateDir;
      ExecStart = "${snapshotScript}/bin/grafana-snapshot-sync";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ stateDir ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
    environment = {
      PLAYWRIGHT_CORE_PATH = "${pkgs.playwright-driver}";
      STATE_DIR = stateDir;
      SNAPSHOT_DIR = "${stateDir}/snapshots";
      MIN_CHANGE_PERCENT = "0.3";
      HOME = homeDir;
      SNAPSHOT_GIT_NAME = locality.snapshotGitName;
      SNAPSHOT_GIT_EMAIL = locality.snapshotGitEmail;
      SNAPSHOT_REPO_URL = locality.snapshotRepoUrl;
      SNAPSHOT_BRANCH = "snapshots";
      PUBLISH_REPO_DIR = locality.snapshotPublishDir;
    };
  };

  systemd.timers.grafana-snapshot-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "6h";
      AccuracySec = "1min";
      Persistent = true;
      Unit = "grafana-snapshot-sync.service";
    };
  };
}
