{ pkgs, ... }:

let
  promtailConfig = pkgs.writeText "promtail.yaml" (
    builtins.toJSON {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      positions.filename = "/var/lib/promtail/positions.yaml";
      clients = [ { url = "http://127.0.0.1:3100/loki/api/v1/push"; } ];
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
      Restart = "always";
    };
  };
}
