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

All services are Nix-declared in [`modules/observability.nix`](https://github.com/RomeoCavazza/setup-os/blob/main/modules/observability.nix) and activated with `nixos-rebuild`.


## Dashboards Overview

The monitoring suite consists of three specialized views sharing a **unified 25-gauge operational rail** on the left. This rail provides a constant heartbeat of the system (Uptime, PSI, Temp, Store, Incidents).

Snapshots are checked every 15 minutes and published when visual delta exceeds 0.3%. The dashboards are maintained as Jsonnet sources and rendered into committed Grafana JSON.

Regeneration command:
```bash
cd /etc/nixos
sudo -E nix shell nixpkgs#jsonnet nixpkgs#jq -c [./config/bin/grafana-generate](https://github.com/RomeoCavazza/setup-os/blob/main/config/bin/grafana-generate)
```

### 1. NixOS System Cockpit

The primary view for overall system health and real-time monitoring.

![NixOS Metrics Live](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/live-dashboard.png)

Source: [config/grafana/src/nix-dashboard.jsonnet](https://github.com/RomeoCavazza/setup-os/blob/main/config/grafana/src/nix-dashboard.jsonnet)

- **Operational Rail (25 Gauges)**: CPU/RAM/PSI, Thermal sensors, Store Fill, Journal Incidents, hyprland status.
- **Resource Pressure Heatmap**: Multi-dimensional view of CPU/Mem/IO pressure with sharpened raw spikes.
- **Resource Pressure Timeline**: Historical PSI trends for identifying bottlenecks.
- **Temperature Sensors**: Detailed chip and thermal zone monitoring (CPU, NVMe, etc.).
- **NVIDIA GPU Metrics**: VRAM occupancy and real-time Power Draw (Watts).

### 2. Nix Efficiency & Store Health

Tracking drift, generation debt, and the cost of system rebuilds.

![Nix Efficiency](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/nix-efficiency.png)

Source: [config/grafana/src/nix-efficiency-dashboard.jsonnet](https://github.com/RomeoCavazza/setup-os/blob/main/config/grafana/src/nix-efficiency-dashboard.jsonnet)

- **Generation Debt**: `nix_generations_count` and `nix_flake_lock_age_seconds`.
- **Closure Shape**: `nix_closure_bytes` vs `nix_store_bytes` ratio.
- **Store Performance**: Rebuild activity calendar and scheduler pulse.
- **System stress context**: Includes Pressure Timeline and Thermal sensors to monitor impact of heavy builds.

### 3. Incident Diagnostics

Log correlation matched with hardware risk signals for fast root-cause analysis.

![Incident Dashboard](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/live/incident-dashboard.png)

Source: [config/grafana/src/incident-correlation-dashboard.jsonnet](https://github.com/RomeoCavazza/setup-os/blob/main/config/grafana/src/incident-correlation-dashboard.jsonnet)

- **Incident Risk River**: Stream graph of disk/net risk signals vs log volume.
- **Journal Logs**: Filtered incident feed (`failed`, `panic`, `segfault`, etc.).
- **Network & Disk Faults**: I/O throughput vs latency and network error rates.
- **Correlation Context**: Includes Pressure Timeline and GPU metrics to match log events with hardware stress.

---

### Prometheus Metric Source

Prometheus is the verification layer. If a dashboard panel looks wrong, this is where raw `nix_*` or `node_*` series are checked first.

![Prometheus query view](https://raw.githubusercontent.com/RomeoCavazza/setup-os/refs/heads/main/docs/assets/prometheus.png)

### Log Correlation Labels (Promtail)

Promtail adds a `component` label for targeted LogQL queries:
- `component="display"`: Hyprland/Display stack.
- `component="build"`: Nix build/rebuild logs.
- `component="system"`: Default systemd journal.

---

## Technical Pipeline

1. **Source**: Dashboards defined in [`config/grafana/src/*.jsonnet`](https://github.com/RomeoCavazza/setup-os/blob/main/config/grafana/src/).
2. **Compile**: [`grafana-generate`](https://github.com/RomeoCavazza/setup-os/blob/main/config/bin/grafana-generate) produces the provisioned JSON in [`config/grafana/dashboards/`](https://github.com/RomeoCavazza/setup-os/blob/main/config/grafana/dashboards/).
3. **Capture**: [`grafana-snapshot-sync.timer`](https://github.com/RomeoCavazza/setup-os/blob/main/config/bin/grafana-snapshot-sync) captures PNGs every 15m.
4. **Publish**: PNGs reaching >0.5% delta are pushed to [`docs/assets/live/`](https://github.com/RomeoCavazza/setup-os/blob/main/docs/assets/live/).

Rendered assets path: [`docs/assets/live/`](https://github.com/RomeoCavazza/setup-os/blob/main/docs/assets/live/).
Publisher checkout: `/var/lib/grafana-snapshot-sync/setup-os`.
