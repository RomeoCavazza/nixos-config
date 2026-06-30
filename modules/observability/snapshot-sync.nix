{ config, pkgs, ... }:

let
  repoRoot = ../../.;
  user = "tco";
  homeDir = config.users.users.${user}.home;
  repoCheckout = "/etc/nixos";
  liveAssetsDir = "${repoCheckout}/docs/assets/live";

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
    text = ''
      export PLAYWRIGHT_CORE_PATH=${pkgs.playwright-driver}
    ''
    + builtins.readFile (repoRoot + "/config/bin/grafana-snapshot-sync");
  };
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana-snapshot-sync 0755 ${user} users -"
    "d ${liveAssetsDir} 0755 ${user} users -"
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
      WorkingDirectory = repoCheckout;
      ExecStart = "${snapshotScript}/bin/grafana-snapshot-sync";
    };
    environment = {
      REPO_DIR = repoCheckout;
      MIN_CHANGE_PERCENT = "0.3";
      HOME = homeDir;
      SNAPSHOT_GIT_NAME = "Romeo Cavazza";
      SNAPSHOT_GIT_EMAIL = "romeo.cavazza@users.noreply.github.com";
      SNAPSHOT_REPO_URL = "git@github.com:RomeoCavazza/nixos-config.git";
      SNAPSHOT_BRANCH = "main";
      PUBLISH_REPO_DIR = "/var/lib/grafana-snapshot-sync/nixos-config";
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
