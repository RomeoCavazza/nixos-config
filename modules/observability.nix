{ pkgs, ... }:

let
  textfileDir = "/var/lib/node_exporter/textfile_collector";

  nixMetricsScript = pkgs.writeShellApplication {
    name = "nix-metrics";
    runtimeInputs = [ pkgs.nix pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ../config/bin/nix-metrics;
  };

  snapshotScript = pkgs.writeShellApplication {
    name = "grafana-snapshot-sync";
    runtimeInputs = [ pkgs.curl pkgs.git pkgs.imagemagick pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ../config/bin/grafana-snapshot-sync;
  };

  promtailConfig = pkgs.writeText "promtail.yaml" (builtins.toJSON {
    server = {
      http_listen_port = 9080;
      grpc_listen_port = 0;
    };
    positions.filename = "/var/lib/promtail/positions.yaml";
    clients = [{ url = "http://127.0.0.1:3100/loki/api/v1/push"; }];
    scrape_configs = [{
      job_name = "journal";
      journal = {
        max_age = "12h";
        labels.job = "systemd-journal";
      };
      relabel_configs = [
        {
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }
        {
          source_labels = [ "__journal__systemd_unit" ];
          regex = ".*";
          replacement = "system";
          target_label = "component";
        }
        {
          source_labels = [ "__journal__systemd_unit" ];
          regex = "(hyprland|hypr.*)\\.service";
          replacement = "display";
          target_label = "component";
        }
        {
          source_labels = [ "__journal__systemd_unit" ];
          regex = "(nixos-rebuild|nix-daemon|nixos-upgrade).*";
          replacement = "build";
          target_label = "component";
        }
      ];
    }];
  });

  grafanaDashboardsDir = pkgs.runCommand "grafana-dashboards" {} ''
    mkdir -p $out
    cp ${../config/grafana/nix-dashboard.json} $out/live-dashboard.json
    cp ${../config/grafana/nix-efficiency-dashboard.json} $out/nix-efficiency-dashboard.json
    cp ${../config/grafana/incident-correlation-dashboard.json} $out/incident-correlation-dashboard.json
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
    "d /var/lib/promtail 0755 root root -"
    "d /etc/nixos/docs/assets/live 0755 tco users -"
  ];

  systemd.services.nix-metrics = {
    description = "Collect Nix store metrics for Prometheus";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nixMetricsScript}/bin/nix-metrics";
    };
  };

  systemd.timers.nix-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      Unit = "nix-metrics.service";
    };
  };

  systemd.services.grafana-snapshot-sync = {
    description = "Render Grafana dashboards and sync changed PNGs to git";
    after = [ "grafana.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "tco";
      Group = "users";
      WorkingDirectory = "/etc/nixos";
      ExecStart = "${snapshotScript}/bin/grafana-snapshot-sync";
      Environment = [
        "MIN_CHANGE_PERCENT=5"
        "HOME=/home/tco"
        "SNAPSHOT_GIT_NAME=Romeo Cavazza"
        "SNAPSHOT_GIT_EMAIL=romeo.cavazza@users.noreply.github.com"
      ];
    };
  };

  systemd.timers.grafana-snapshot-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "1h";
      Unit = "grafana-snapshot-sync.service";
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    scrapeConfigs = [
      { job_name = "prometheus"; static_configs = [{ targets = [ "127.0.0.1:9090" ]; }]; }
      { job_name = "node"; static_configs = [{ targets = [ "127.0.0.1:9100" ]; }]; }
      { job_name = "loki"; static_configs = [{ targets = [ "127.0.0.1:3100" ]; }]; }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server.http_listen_port = 3100;
      common = {
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
      };
      schema_config.configs = [{
        from = "2024-01-01";
        store = "tsdb";
        object_store = "filesystem";
        schema = "v13";
        index = { prefix = "index_"; period = "24h"; };
      }];
    };
  };

  systemd.services.promtail = {
    description = "Promtail Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "loki.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.promtail-bin}/bin/promtail -config.file=${promtailConfig}";
      Restart = "always";
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
      };
      auth.anonymous = {
        enabled = true;
        org_role = "Viewer";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:3100";
          editable = false;
        }
      ];
      dashboards.settings.providers = [{
        name = "nixos";
        type = "file";
        options.path = grafanaDashboardsDir;
      }];
    };
  };

  environment.systemPackages = with pkgs; [
    prometheus
    loki
    promtail-bin
    nvtopPackages.full
    imagemagick
  ];
}
