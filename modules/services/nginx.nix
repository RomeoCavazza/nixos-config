_:

let
  ports = import ../observability/ports.nix;
  loopback = "127.0.0.1";

  # Socket Workhorse de GitLab
  gitlabSocket = "http://unix:/run/gitlab/gitlab-workhorse.socket";

  listenOn = port: [
    {
      addr = loopback;
      inherit port;
      ssl = false;
    }
  ];

  okResponse = {
    return = "200 'ok'";
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
          extraConfig = ''
            proxy_pass ${upstream};
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            proxy_set_header Host              ${forwardedHost};
            proxy_set_header X-Forwarded-Host  ${forwardedHost};

            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

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
      "grafana.localhost-proxy" = {
        serverName = "localhost";
        listen = listenOn ports.grafanaProxy;
        locations."/" = {
          proxyPass = "http://${loopback}:${toString ports.grafana}";
          proxyWebsockets = true;
        };
      };

      "dev.localhost-proxy" = mkLocalProxy {
        serverName = "dev.localhost";
        port = 8082;
        upstream = "http://${loopback}:80";
      };

      "localhost-8084-proxy" = mkLocalProxy {
        serverName = "localhost";
        port = 8084;
        upstream = "http://${loopback}:80";
        forwardedHost = "localhost";
      };

      # ── GitLab ────────────────────────────────────────────────────────────
      "gitlab.localhost-proxy" = {
        serverName = "gitlab.localhost";
        listen = listenOn ports.gitlabProxy;
        locations = {
          "/" = {
            extraConfig = ''
              proxy_pass ${gitlabSocket};
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection $connection_upgrade;

              proxy_set_header Host              gitlab.localhost:8930;
              proxy_set_header X-Forwarded-Host  gitlab.localhost:8930;
              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # Gros fichiers : LFS, artefacts CI, uploads
              client_max_body_size 2G;
              proxy_read_timeout   300;
              proxy_connect_timeout 300;
            '';
          };
        };
      };

      # ── GitLab Pages ──────────────────────────────────────────────────────
      "gitlab-pages-proxy" = {
        serverName = "pages.localhost";
        serverAliases = [ "*.pages.localhost" ];
        listen = listenOn ports.gitlabPages;
        locations."/" = {
          extraConfig = ''
            proxy_pass http://${loopback}:8090;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
      };
    };
  };
}
