{ config, pkgs, lib, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "15d";

    scrapeConfigs = [
      { job_name = "prometheus";
        static_configs = [{ targets = [ "127.0.0.1:9090" ]; }];
      }
      { job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }
      { job_name = "loki";
        static_configs = [{ targets = [ "127.0.0.1:3100" ]; }];
      }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
      };

      common = {
        instance_addr = "127.0.0.1";
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
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        retention_period = "168h";
      };
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = { http_listen_port = 9080; grpc_listen_port = 0; };
      positions = { filename = "/var/lib/promtail/positions.yaml"; };
      clients = [{ url = "http://127.0.0.1:3100/loki/api/v1/push"; }];

      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = { job = "systemd-journal"; };
          };
          relabel_configs = [
            { source_labels = [ "__journal__systemd_unit" ]; target_label = "unit"; }
          ];
        }
      ];
    };
  };

  systemd.services.promtail.serviceConfig = {
    StateDirectory = "promtail";
    CacheDirectory = "promtail";
    ReadWritePaths = [ "/var/lib/promtail" ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "127.0.0.1";
      http_port = 3000;
      domain = "localhost";
    };
    settings.security.secret_key = "shellgeist-super-secret-key-change-me";
  };

  environment.systemPackages = with pkgs; [
    prometheus
    loki
    promtail
    nvtopPackages.full
  ];

  # If everything is local-only, no need to open firewall ports
  networking.firewall.allowedTCPPorts = lib.mkForce [ ];
}
