_:

let
  ports = import ./ports.nix;
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = ports.prometheus;
    extraFlags = [ "--storage.tsdb.retention.time=15d" ];
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.prometheus}" ]; } ];
      }
      {
        job_name = "node";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.node}" ]; } ];
      }
      {
        job_name = "nvidia";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.nvidia}" ]; } ];
      }
      {
        job_name = "loki";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.loki}" ]; } ];
      }
      {
        job_name = "gitlab";
        static_configs = [ { targets = [ "127.0.0.1:${toString ports.gitlab}" ]; } ];
        metrics_path = "/-/metrics";
        # GitLab exige un token Bearer pour /-/metrics en production
        # Pour l'instant (local) on peut laisser sans auth si allow_local_requests_from_web_hooks_and_services = true
      }
    ];
  };
}
