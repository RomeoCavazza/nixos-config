{ pkgs, ... }:

let
  ports = import ./ports.nix;
  promtailConfig = pkgs.writeText "promtail.yaml" (
    builtins.toJSON {
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = ports.promtail;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = 0;
        graceful_shutdown_timeout = "5s";
      };
      positions = {
        filename = "/var/lib/promtail/positions.yaml";
        sync_period = "2s";
      };
      clients = [
        {
          url = "http://127.0.0.1:${toString ports.loki}/loki/api/v1/push";
          timeout = "3s";
          backoff_config = {
            min_period = "250ms";
            max_period = "2s";
            max_retries = 3;
          };
        }
      ];
      scrape_configs = [
        {
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
            {
              source_labels = [ "__journal__systemd_unit" ];
              regex = "(restic-.*|restic-restore-drill)\\.service";
              replacement = "backup";
              target_label = "component";
            }
          ];
        }
      ];
    }
  );
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/promtail 0755 root root -"
  ];

  systemd.services.promtail = {
    description = "Promtail Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "loki.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.promtail-bin}/bin/promtail -config.file=${promtailConfig}";
      Restart = "on-failure";
      RestartSec = "2s";
      TimeoutStopSec = "12s";
    };
  };
}
