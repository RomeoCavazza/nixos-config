# Grafana Dashboards

Dashboards are maintained as Jsonnet sources in `src/` and rendered into the
provisioned JSON files in this directory.

Grafana reads:

- `nix-dashboard.json`
- `nix-efficiency-dashboard.json`
- `incident-correlation-dashboard.json`

Regenerate after editing `src/`:

```sh
nix shell nixpkgs#jsonnet -c config/bin/grafana-generate
```

The local library in `src/lib/dashboard.libsonnet` intentionally keeps a small
Grafonnet-style API instead of vendoring a large external dashboard library.
