{
  config,
  locality,
  pkgs,
  ...
}:

let
  ports = import ./ports.nix;
  # Warn (don't fail) when the config/grafana submodule is uninitialized, so a
  # missing dashboards dir is visible in the journal instead of silently empty.
  dashboardsCheck = pkgs.writeShellScript "grafana-dashboards-check" ''
    if [ -z "$(${pkgs.coreutils}/bin/ls -A ${locality.repoCheckout}/config/grafana 2>/dev/null)" ]; then
      echo "WARNING: ${locality.repoCheckout}/config/grafana is empty — git submodule not initialized? Run 'git submodule update --init'. Grafana will provision no dashboards." >&2
    fi
  '';
in
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
        http_port = ports.grafana;
        root_url = "http://localhost:${toString ports.grafanaProxy}/";
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
          url = "http://127.0.0.1:${toString ports.prometheus}";
          isDefault = true;
          editable = false;
        }
        {
          uid = "P8E80F9AEF21F6940";
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString ports.loki}";
          editable = false;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "nixos";
          type = "file";
          options.path = "${locality.repoCheckout}/config/grafana";
        }
      ];
    };
  };

  systemd.services.grafana.serviceConfig.ExecStartPre = [ "${dashboardsCheck}" ];
}
