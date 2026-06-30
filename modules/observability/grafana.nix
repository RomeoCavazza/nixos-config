{ config, pkgs, ... }:

{
  sops.secrets.grafana_secret_key = {
    owner = "grafana";
    group = "grafana";
    mode = "0400";
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
        disable_gravatar = true;
        secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      users = {
        allow_sign_up = false;
        allow_org_create = false;
        auto_assign_org_role = "Viewer";
        viewers_can_edit = false;
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
      dashboards.settings.providers = [
        {
          name = "nixos";
          type = "file";
          options.path = "/etc/nixos/config/grafana";
        }
      ];
    };
  };
}
