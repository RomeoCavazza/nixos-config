# Grafana Dashboards

Dashboards are maintained as Jsonnet sources in `src/` and rendered into the
provisioned JSON files in this directory.

Grafana reads the Trinity dashboards plus one experimental compiled view:

- `nixos-engine.json` - immediate performance pulse: CPU, RAM, load, thermals, PSI
- `nixos-forge.json` - Nix build and store state: growth, closures, generations
- `nixos-black-box.json` - diagnostics: journald incidents, disk IO latency, network faults
- `nixos-compiled.json` - experimental single-page compilation of Engine, Forge, and Black Box

Regenerate after editing `src/`:

```sh
nix shell nixpkgs#jsonnet -c config/bin/grafana-generate
```

The local library in `src/lib/dashboard.libsonnet` intentionally keeps a small
Grafonnet-style API instead of vendoring a large external dashboard library.

Metric ownership is intentionally strict in the three canonical dashboards:
Engine does not show store or logs, Forge does not show host performance or
logs, and Black Box does not show Nix store/build gauges. The compiled view
imports those dashboards onto one page for visual comparison only.
