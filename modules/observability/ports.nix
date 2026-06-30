# Single source of truth for observability service ports.
# Imported (import ./ports.nix) by the observability modules and by the nginx
# grafana proxy, so each port is declared exactly once.
#
# NOTE: this is a plain attrset, not a NixOS module — it is intentionally NOT
# listed in default.nix's imports.
{
  prometheus = 9090;
  node = 9100;
  nvidia = 9835;
  loki = 3100;
  lokiGrpc = 9095;
  grafana = 3001;
  grafanaProxy = 3000;
  promtail = 9080;
}
