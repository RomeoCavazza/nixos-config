<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/logo/graphana.png" alt="Grafana" width="26" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/logo/loki.png" alt="Loki" width="26" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/logo/prometheus.png" alt="Prometheus" width="26" />
</p>

## Stack Summary

The stack is intentionally small: Prometheus and Node Exporter handle metrics, Loki and Promtail handle logs, and Grafana ties the signals together.

| Component | Endpoint | Role |
|---|---|---|
| Prometheus | `localhost:9090` | Metrics TSDB and query engine |
| Node Exporter | `localhost:9100` | Host metrics plus textfile collector |
| Loki | `localhost:3100` | Centralized logs |
| Promtail | systemd service | Journald scraping and labeling |
| Grafana | `localhost:3000` | Dashboards and correlation UI |

All services are Nix-declared and activated with `nixos-rebuild`.


## Live Snapshots

The three live views are the operational contract for this machine: health now, drift over time, then incident explanation. Each snapshot embeds the metrics it is responsible for instead of relying on a separate metric index. Snapshots are checked every 15 minutes and published when visual delta exceeds 0.5%.

The dashboards are maintained as Jsonnet sources and rendered into committed Grafana JSON. Shared panel helpers live in `config/grafana/src/lib/dashboard.libsonnet`, with a small Grafonnet-style API.

Regeneration command:
```bash
cd /etc/nixos
sudo -E nix shell nixpkgs#jsonnet nixpkgs#jq -c ./config/bin/grafana-generate
```

### NixOS Metrics

Live cockpit for pressure, retained state, store size, closure size, and rebuild cost. This is the first view to check when the machine feels slow or a rebuild looks suspicious.


![NixOS Metrics Live](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/live-dashboard.png)

- Pressure now: `nix_pressure_cpu_avg10`, `nix_pressure_io_some_avg10`, `nix_pressure_mem_some_avg10`
- Retained state: `nix_generation`, `nix_generations_count`
- Footprint: `nix_store_bytes`, `nix_store_paths`, `nix_closure_bytes`, `nix_closure_paths`
- Rebuild outcome: `nix_rebuild_duration_ms`, `nix_rebuild_success`
- Source: `config/grafana/src/nix-dashboard.jsonnet` -> `config/grafana/nix-dashboard.json`

### Nix Efficiency

Drift dashboard for freshness, generation debt, closure efficiency, and rebuild cost over time. This is where stale inputs and retained-generation debt become visible before they turn into cleanup work.


![Nix Efficiency](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/nix-efficiency.png)

- Freshness: `nix_flake_lock_age_seconds`
- Generation debt: `nix_generations_count`
- Closure shape: `nix_closure_bytes`, `nix_closure_paths`
- Store pressure: `nix_store_bytes`
- Rebuild cost: `nix_rebuild_duration_ms`
- Source: `config/grafana/src/nix-efficiency-dashboard.jsonnet` -> `config/grafana/nix-efficiency-dashboard.json`

### Incident Correlation

PSI spikes aligned with journald logs for fast root-cause analysis. This view answers the next question after a pressure spike: which part of the system was talking at the same time?


![Incident Dashboard](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/incident-dashboard.png)

- Pressure signal: `nix_pressure_cpu_avg10`, `nix_pressure_io_some_avg10`, `nix_pressure_mem_some_avg10`
- Build context: `nix_rebuild_duration_ms`, `nix_rebuild_success`
- Log context: `{job="systemd-journal",component=~"display|build"}`
- Source: `config/grafana/src/incident-correlation-dashboard.jsonnet` -> `config/grafana/incident-correlation-dashboard.json`


### Prometheus Metric Source

Prometheus is the verification layer between the local collectors and Grafana. When a dashboard panel looks wrong, this is where the raw `nix_*` series are checked first: if the query is fresh here, the issue is in dashboard rendering; if it is missing here, the issue is in collection.

![Prometheus query view](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/prometheus.png)

### Log Correlation Labels (Promtail)

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
9. This wiki page references `refs/heads/main` raw URLs so the images follow the latest pushed snapshots.

Rendered assets path: `docs/assets/live/`.

Publisher checkout: `/var/lib/grafana-snapshot-sync/setup-os`.

The publisher checkout is also the comparison baseline for PNG deltas. The timer does not rewrite `/etc/nixos/docs/assets/live`, so the system configuration checkout stays focused on source changes instead of generated snapshot noise.

Operational note: Grafana remains the live source of truth. The wiki is a near-live documentation mirror: timer cadence plus raw GitHub/browser cache.
