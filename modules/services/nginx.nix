_:

let
  ports = import ../observability/ports.nix;
  loopback = "127.0.0.1";

  listenOn = port: [
    {
      addr = loopback;
      inherit port;
      ssl = false;
    }
  ];

  okResponse = {
    return = "200 'ok'\n";
    extraConfig = "add_header Content-Type text/plain;";
  };

  mkLocalProxy =
    {
      serverName,
      port,
      upstream,
      forwardedHost ? serverName,
    }:
    {
      inherit serverName;
      listen = listenOn port;
      locations = {
        "/" = {
          proxyPass = upstream;
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host              ${forwardedHost};
            proxy_set_header X-Forwarded-Host  ${forwardedHost};

            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        # Cheap local smoke checks for these helper proxies. The actual upstream
        # can still be down; app-specific health checks should target real routes.
        "=/" = okResponse;
        "/health" = okResponse;
      };
    };
in
{
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedGzipSettings = true;

    appendHttpConfig = ''
      proxy_headers_hash_bucket_size 128;
      proxy_headers_hash_max_size 1024;
    '';

    virtualHosts = {
      # Grafana helper: keeps localhost:3000 pointing at the real Grafana port.
      "grafana.localhost-proxy" = {
        serverName = "localhost";
        listen = listenOn ports.grafanaProxy;
        locations."/" = {
          proxyPass = "http://${loopback}:${toString ports.grafana}";
          proxyWebsockets = true;
        };
      };

      # 8081 is intentionally free for OpsWarden's `client_web` Docker Compose
      # service. VIGIL expects the web client at http://localhost:8081.
      "dev.localhost-proxy" = mkLocalProxy {
        serverName = "dev.localhost";
        port = 8082;
        upstream = "http://${loopback}:80";
      };

      # Local localhost -> :80 proxy, moved away from 8081 so it no longer
      # shadows OpsWarden's jury-facing Compose port.
      "localhost-8084-proxy" = mkLocalProxy {
        serverName = "localhost";
        port = 8084;
        upstream = "http://${loopback}:80";
        forwardedHost = "localhost";
      };
    };
  };
}
