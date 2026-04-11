local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'NixOS Metrics',
  'nixos-metrics',
  '30s',
  'Live health view for Nix pressure, rebuild cost, and store growth.'
) {
  panels: [
    g.textPanel(
      0,
      'Live system state',
      '**Read left to right:** render freshness, Prometheus freshness, pressure, retained state, then trends. Grafana is the source of truth; PNG snapshots are a near-live mirror.',
      0, 0, 24
    ),
    g.rowPanel(20, 'Health strip', 2),
    g.statPanel(
      21,
      'Rendered',
      'time() * 1000',
      0, 3, 4,
      unit='dateTimeAsIso',
      colorMode='none',
      graphMode='none'
    ),
    g.statPanel(
      22,
      'Prometheus Data Age',
      'time() - max(timestamp(nix_store_bytes))',
      4, 3, 4,
      unit='s',
      decimals=0,
      thresholds=g.greenYellowRed(60, 300),
      mappings=[g.noDataMapping]
    ),
    g.statPanel(
      23,
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      8, 3, 4,
      legend='pressure',
      unit='percent',
      decimals=1,
      min=0,
      max=100,
      thresholds=g.greenYellowRed(10, 30)
    ),
    g.statPanel(
      24,
      'Generation',
      'nix_generation',
      12, 3, 4,
      legend='generation',
      unit='none',
      thresholds=g.thresholds([{ color: 'green', value: null }])
    ),
    g.statPanel(
      25,
      'Store Size',
      'nix_store_bytes',
      16, 3, 4,
      legend='store',
      unit='decbytes',
      thresholds=g.greenYellowRed(80000000000, 140000000000)
    ),
    g.statPanel(
      26,
      'Closure Size',
      'nix_closure_bytes',
      20, 3, 4,
      legend='closure',
      unit='decbytes',
      thresholds=g.greenYellowRed(1000000000000, 1500000000000)
    ),
    g.rowPanel(30, 'Pressure now', 6),
    g.gaugePanel(1, 'CPU Pressure', 'nix_pressure_cpu_avg10', 'cpu', 0, 7, 8),
    g.gaugePanel(2, 'IO Pressure', 'nix_pressure_io_some_avg10', 'io', 8, 7, 8),
    g.gaugePanel(3, 'RAM Pressure', 'nix_pressure_mem_some_avg10', 'mem', 16, 7, 8),
    g.rowPanel(31, 'Trends', 12),
    g.timeseriesPanel(
      9,
      'Nix Store Size over Time',
      [
        { expr: 'nix_store_bytes', legend: 'total store' },
        { expr: 'nix_closure_bytes', legend: 'current closure' },
      ],
      0, 13, 24,
      h=7,
      unit='decbytes'
    ),
    g.timeseriesPanel(
      11,
      'Rebuild Duration',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration s' }],
      0, 20, 24,
      h=7,
      unit='s'
    ),
  ],
}
