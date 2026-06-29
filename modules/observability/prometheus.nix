_:

{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    extraFlags = [ "--storage.tsdb.retention.time=15d" ];
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
      }
      {
        job_name = "node";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
      {
        job_name = "nvidia";
        static_configs = [ { targets = [ "127.0.0.1:9835" ]; } ];
      }
      {
        job_name = "loki";
        static_configs = [ { targets = [ "127.0.0.1:3100" ]; } ];
      }
    ];
  };
}
