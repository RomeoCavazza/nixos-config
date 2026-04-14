{
  config,
  pkgs,
  lib,
  ...
}:

let
  grafanaAquamarineCss =
    pkgs.runCommand "grafana-aquamarine-css"
      {
        nativeBuildInputs = [ pkgs.dart-sass ];
      }
      ''
        mkdir -p $out source/config/grafana/theme source/config/scss

        cp ${../config/grafana/theme/aquamarine.scss} source/config/grafana/theme/aquamarine.scss
        cp -R ${../config/scss}/. source/config/scss/

        sass \
          --no-source-map \
          --style=expanded \
          source/config/grafana/theme/aquamarine.scss \
          $out/aquamarine.css
      '';
in
{
  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedGzipSettings = true;

    virtualHosts = {
      "grafana.localhost-proxy" = {
        serverName = "localhost";
        listen = [
          {
            addr = "127.0.0.1";
            port = 3000;
            ssl = false;
          }
        ];
        locations = {
          "=/theme/grafana-aquamarine.css" = {
            alias = "${grafanaAquamarineCss}/aquamarine.css";
            extraConfig = ''
              types { text/css css; }
              default_type text/css;
              add_header Cache-Control "no-store";
            '';
          };

          "/" = {
            proxyPass = "http://127.0.0.1:3001";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Accept-Encoding   "";

              sub_filter_once on;
              sub_filter
                '</head>'
                '<link rel="stylesheet" type="text/css" href="/theme/grafana-aquamarine.css"></head>';
            '';
          };
        };
      };

      "localhost-proxy" = {
        serverName = "localhost";
        listen = [
          {
            addr = "127.0.0.1";
            port = 8081;
            ssl = false;
          }
        ];
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:80";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host              localhost;
              proxy_set_header X-Forwarded-Host  localhost;

              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };

          "=/" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
          "/health" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
        };
      };

      "dev.localhost-proxy" = {
        serverName = "dev.localhost";
        listen = [
          {
            addr = "127.0.0.1";
            port = 8082;
            ssl = false;
          }
        ];
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:80";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host              dev.localhost;
              proxy_set_header X-Forwarded-Host  dev.localhost;

              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };

          "=/" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
          "/health" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
        };
      };

      "streamlit.localhost-proxy" = {
        serverName = "streamlit.localhost";
        listen = [
          {
            addr = "127.0.0.1";
            port = 8083;
            ssl = false;
          }
        ];
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8501";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host              streamlit.localhost;
              proxy_set_header X-Forwarded-Host  streamlit.localhost;

              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };

          "=/" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
          "/health" = {
            return = "200 'ok'\n";
            extraConfig = "add_header Content-Type text/plain;";
          };
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    8081
    8082
    8083
  ];
}
