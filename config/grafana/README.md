# Grafana Dashboards

Dashboards are maintained as Jsonnet sources in `src/` and rendered into the
provisioned JSON files in this directory. The canonical panel library lives in
`src/nixos-compiled.jsonnet` (25 rail gauges and 16 graph modules). The three
legacy views pick panels from that source by title, so every gauge and module
has exactly one definition.

Grafana provisions four dashboards:

- `nixos-metrics.json` (UID `nixos-metrics`) — host performance pulse: CPU,
  memory, load, pressure, thermals, GPU.
- `nix-efficiency.json` (UID `nix-efficiency`) — Nix store and rebuild state:
  closure growth, generations, rebuild activity, store pressure.
- `incident-correlation.json` (UID `incident-correlation`) — diagnostics:
  journald incidents, disk I/O latency, network faults, thermal detail.
- `nixos-compiled.json` (UID `nixos-compiled`) — single-page view of every
  panel for visual comparison.

Panel distribution across the three legacy views:

| Source | Rail gauges | Graph modules |
| --- | --- | --- |
| `nix-dashboard.jsonnet` → `nixos-metrics.json` | 10 | 7 |
| `nix-efficiency-dashboard.jsonnet` → `nix-efficiency.json` | 8 | 4 |
| `incident-correlation-dashboard.jsonnet` → `incident-correlation.json` | 7 | 5 |
| **Total** | **25** | **16** |

Regenerate after editing `src/`:

```sh
nix shell nixpkgs#jsonnet nixpkgs#jq -c config/bin/grafana-generate
```

The local library in `src/lib/dashboard.libsonnet` intentionally keeps a small
Grafonnet-style API instead of vendoring a large external dashboard library.
