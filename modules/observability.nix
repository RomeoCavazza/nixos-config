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
    scrapeConfigs = [
      { job_name = "prometheus"; static_configs = [{ targets = ["127.0.0.1:9090"]; }]; }
      { job_name = "node"; static_configs = [{ targets = ["127.0.0.1:9100"]; }]; }
      { job_name = "loki"; static_configs = [{ targets = ["127.0.0.1:3100"]; }]; }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server.http_listen_port = 3100;
      common = {
        path_prefix = "/var/lib/loki";
        storage.filesystem = { chunks_directory = "/var/lib/loki/chunks"; rules_directory = "/var/lib/loki/rules"; };
        replication_factor = 1;
      };
      schema_config.configs = [{ from = "2024-01-01"; store = "tsdb"; object_store = "filesystem"; schema = "v13"; index = { prefix = "index_"; period = "24h"; }; }];
    };
  };

  # LE SERVICE MANUEL QUI SAUVE TON INSTALL
  systemd.services.promtail = {
    description = "Promtail Service (Bypassing NixOS Assertion)";
    wantedBy = [ "multi-user.target" ];
    after = [ "loki.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.promtail-bin}/bin/promtail -config.file=${pkgs.writeText "promtail.yaml" (builtins.toJSON {
        server = { http_listen_port = 9080; grpc_listen_port = 0; };
        positions = { filename = "/var/lib/promtail/positions.yaml"; };
        clients = [{ url = "http://127.0.0.1:3100/loki/api/v1/push"; }];
        scrape_configs = [{
          job_name = "journal";
          journal = { max_age = "12h"; labels = { job = "systemd-journal"; }; };
          relabel_configs = [{ source_labels = [ "__journal__systemd_unit" ]; target_label = "unit"; }];
        }];
      })}";
      Restart = "always";
    };
  };

  services.grafana = {
    enable = true;
    settings.server = { http_addr = "127.0.0.1"; http_port = 3000; };
  };

  environment.systemPackages = with pkgs; [ prometheus loki promtail-bin nvtopPackages.full ];
}
