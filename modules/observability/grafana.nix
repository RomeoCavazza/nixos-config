{ pkgs, ... }:

{
  # TODO(security): this Grafana secret_key is committed in plaintext in a public
  # repo. Migrate to sops-nix in the dedicated security run — do NOT change the
  # mechanism here (this run is a pure split).
  environment.etc."grafana-secret-key".text = "SW2YcwTIb9zpOOhoPsMm";

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
          uid = "PBFA97CFB590B2093";
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
        }
        {
          uid = "P8E80F9AEF21F6940";
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
        options.path = "/etc/nixos/config/grafana";
      }];
    };
  };
}
