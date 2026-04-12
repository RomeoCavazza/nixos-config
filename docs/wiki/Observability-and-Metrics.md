<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/logo/graphana.png" alt="Grafana" width="26" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/logo/loki.png" alt="Loki" width="26" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/main/docs/assets/logo/prometheus.png" alt="Prometheus" width="26" />
</p>

This page documents the local observability stack and the continuous documentation flow around it.

## Live Snapshots (Core)

### NixOS Metrics
Live cockpit for current pressure and rebuild cost.

![NixOS Metrics Live](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/live-dashboard.png)

### Nix Efficiency
Drift dashboard for freshness, generation debt, and closure efficiency.

![Nix Efficiency](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/nix-efficiency.png)

### Incident Correlation
PSI spikes aligned with journald logs for fast root-cause analysis.

![Incident Dashboard](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/incident-dashboard.png)

Snapshots are checked every 15 minutes and published when visual delta exceeds 0.5%.

The three views read as a sequence: health now, drift over time, then incident explanation.

Recent changes:

- Removed freshness redundancy from the main cockpit dashboard
- Kept freshness only in the efficiency dashboard
- Applied explicit dual-axis semantics for closure volume (Bytes) vs path count (Count)
- Visual overhaul: stat panels switched to `colorMode="background"` (full panel coloring on thresholds), timeseries upgraded with `gradientMode="hue"` fills, pressure panels stacked with threshold zone backgrounds

## Stack Summary

The stack is intentionally small: Prometheus and Node Exporter handle metrics, Loki and Promtail handle logs, and Grafana ties the signals together.

| Component | Endpoint | Role |
|---|---|---|
| Prometheus | `localhost:9090` | Metrics TSDB and query engine |
| Node Exporter | `localhost:9100` | Host metrics + textfile collector |
| Loki | `localhost:3100` | Centralized logs |
| Promtail | systemd service | Journald scraping + labeling |
| Grafana | `localhost:3000` | Dashboards and correlation UI |

All services are Nix-declared and activated with `nixos-rebuild`.

## Dashboards

`nixos-metrics` tracks live pressure and rebuild health, `nix-efficiency` tracks drift and closure efficiency, and `incident-correlation` links spikes back to logs.

The dashboards are maintained as code. Grafana still consumes committed JSON
files, but those files are generated from Jsonnet sources:

| Generated dashboard | Source |
|---|---|
| `config/grafana/nix-dashboard.json` | `config/grafana/src/nix-dashboard.jsonnet` |
| `config/grafana/nix-efficiency-dashboard.json` | `config/grafana/src/nix-efficiency-dashboard.jsonnet` |
| `config/grafana/incident-correlation-dashboard.json` | `config/grafana/src/incident-correlation-dashboard.jsonnet` |

Shared panel helpers live in `config/grafana/src/lib/dashboard.libsonnet`, with
a small Grafonnet-style API for stat strips, gauges, time series, rows, logs,
thresholds, and value mappings.

Regeneration command:

```bash
cd /etc/nixos
sudo -E nix shell nixpkgs#jsonnet nixpkgs#jq -c ./config/bin/grafana-generate
```

This keeps dashboard design reviewable in Git while preserving Grafana's simple
JSON provisioning path.

## Key Metrics

These are the signals I watch first when the machine feels slow or stale.

| Metric | Meaning | Typical Use |
|---|---|---|
| `nix_pressure_cpu_avg10` | CPU pressure over 10s window | Detect short saturation events |
| `nix_pressure_io_some_avg10` | IO pressure over 10s window | Spot storage bottlenecks |
| `nix_pressure_mem_some_avg10` | Memory pressure over 10s window | Detect reclaim pressure |
| `nix_closure_bytes` | Current system closure size | Track deployment footprint |
| `nix_closure_paths` | Number of closure paths | Track graph complexity |
| `nix_generations_count` | Retained generations | Manage generation debt |
| `nix_flake_lock_age_seconds` | Flake lock freshness | Detect stale dependency state |

## Log Correlation Labels (Promtail)

Promtail adds a `component` label so dashboard spikes can be matched to the right part of the machine:

- `component="display"` for Hyprland and display stack units
- `component="build"` for Nix build / rebuild units
- `component="system"` as the default fallback

LogQL example:

```logql
{job="systemd-journal",component=~"display|build"}
```

## Continuous Documentation Pipeline

The documentation flow is intentionally quiet:

1. Dashboard sources are edited in `config/grafana/src/*.jsonnet`.
2. `config/bin/grafana-generate` renders the provisioned JSON files.
3. NixOS activates Grafana with the generated dashboards.
4. `grafana-snapshot-sync.timer` runs every 15 minutes.
5. Dashboards are captured via headless browser as PNG.
6. New images are compared with previous versions.
7. Changes over 0.5% are copied into the publisher checkout.
8. The publisher commits `docs/assets/live/*.png` to `setup-os/main`.
9. This wiki page keeps the same Markdown, but its raw GitHub image URLs resolve to the newest pushed PNG after the normal cache window.

Rendered assets path: `docs/assets/live/`.

Publisher checkout: `/var/lib/grafana-snapshot-sync/setup-os`.

The publisher checkout is also the comparison baseline for PNG deltas. The
timer does not rewrite `/etc/nixos/docs/assets/live`, so the system
configuration checkout stays focused on source changes instead of generated
snapshot noise.

Operational note: Grafana remains the live source of truth. The wiki is a
near-live documentation mirror: timer cadence plus raw GitHub/browser cache.
