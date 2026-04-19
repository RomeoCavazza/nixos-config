{ pkgs, ... }:

let
  textfileDir = "/var/lib/node_exporter/textfile_collector";

  nixMetricsScript = pkgs.writeShellApplication {
    name = "nix-metrics";
    runtimeInputs = [ pkgs.nix pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.python3 ];
    text = builtins.readFile ../config/bin/nix-metrics;
  };

  snapshotScript = pkgs.writeShellApplication {
    name = "grafana-snapshot-sync";
    runtimeInputs = [ pkgs.curl pkgs.git pkgs.nodejs pkgs.openssh pkgs.imagemagick pkgs.coreutils pkgs.gawk pkgs.google-chrome pkgs.playwright-driver ];
    text = ''
      export PLAYWRIGHT_CORE_PATH=${pkgs.playwright-driver}
    '' + builtins.readFile ../config/bin/grafana-snapshot-sync;
  };

  hyprMetricsScript = pkgs.writeShellApplication {
    name = "hypr-metrics";
    runtimeInputs = [ pkgs.hyprland pkgs.coreutils pkgs.jq ];
    text = builtins.readFile ../config/bin/hypr-metrics;
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
          # display-manager covers GDM/SDDM; hypr* covers any future hyprland system unit
          regex = "(hyprland|hypr.*|display-manager)\\.service";
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
    cp ${../config/grafana/nixos-engine.json} $out/nixos-engine.json
    cp ${../config/grafana/nixos-forge.json} $out/nixos-forge.json
    cp ${../config/grafana/nixos-black-box.json} $out/nixos-black-box.json
    cp ${../config/grafana/nixos-compiled.json} $out/nixos-compiled.json
  '';
in
{
  environment.etc."grafana-secret-key".text = "SW2YcwTIb9zpOOhoPsMm";

  systemd.tmpfiles.rules = [
    # tco owns the dir so the rebuild wrapper can write nix-rebuild.prom without sudo.
    # nix-metrics runs as root and can write there regardless.
    # node_exporter reads 644 files — no group membership needed.
    "d ${textfileDir} 0755 tco users -"
    "d /var/lib/promtail 0755 root root -"
    "d /var/lib/grafana-snapshot-sync 0755 tco users -"
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

  systemd.services.hypr-metrics = {
    description = "Collect Hyprland workspace and window metrics";
    serviceConfig = {
      Type = "oneshot";
      User = "tco";
      ExecStart = "${hyprMetricsScript}/bin/hypr-metrics";
    };
  };

  systemd.timers.hypr-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
      Unit = "hypr-metrics.service";
    };
  };

  systemd.services.grafana-snapshot-sync = {
    description = "Render Grafana dashboards and sync changed PNGs to git";
    after = [ "grafana.service" "nginx.service" "network-online.target" ];
    wants = [ "nginx.service" "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "tco";
      Group = "users";
      WorkingDirectory = "/etc/nixos";
      ExecStart = "${snapshotScript}/bin/grafana-snapshot-sync";
    };
    environment = {
      MIN_CHANGE_PERCENT = "0.3";
      HOME = "/home/tco";
      SNAPSHOT_GIT_NAME = "Romeo Cavazza";
      SNAPSHOT_GIT_EMAIL = "romeo.cavazza@users.noreply.github.com";
      SNAPSHOT_REPO_URL = "git@github.com:RomeoCavazza/setup-os.git";
      SNAPSHOT_BRANCH = "main";
      PUBLISH_REPO_DIR = "/var/lib/grafana-snapshot-sync/setup-os";
    };
  };

  systemd.timers.grafana-snapshot-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
      AccuracySec = "1min";
      Persistent = true;
      Unit = "grafana-snapshot-sync.service";
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "hwmon" "thermal_zone" "pressure" "systemd" ];
    extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
  };

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9835;
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    extraFlags = [ "--storage.tsdb.retention.time=15d" ];
    scrapeConfigs = [
      { job_name = "prometheus"; static_configs = [{ targets = [ "127.0.0.1:9090" ]; }]; }
      { job_name = "node"; static_configs = [{ targets = [ "127.0.0.1:9100" ]; }]; }
      { job_name = "nvidia"; static_configs = [{ targets = [ "127.0.0.1:9835" ]; }]; }
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
        ring.kvstore.store = "inmemory";
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
      limits_config = {
        retention_period = "15d";
      };
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
        delete_request_store = "filesystem";
        delete_request_cancel_period = "24h";
      };
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
    declarativePlugins = with pkgs.grafanaPlugins; [
      volkovlabs-echarts-panel
      grafana-metricsdrilldown-app
      grafana-lokiexplore-app
      grafana-exploretraces-app
      grafana-pyroscope-app
    ];
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3001;
        root_url = "http://localhost:3000/";
      };
      security = {
        secret_key = "$__file{/etc/grafana-secret-key}";
      };
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };
      feature_toggles.enable = "newGauge";
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
