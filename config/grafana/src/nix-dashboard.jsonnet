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
    g.rowPanel(20, 'System Health — live snapshot', 2),
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
      thresholds=g.greenYellowRedHex(60, 300),
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
      thresholds=g.greenYellowRedHex(10, 30)
    ),
    g.statPanel(
      24,
      'Generation',
      'nix_generation',
      12, 3, 4,
      legend='generation',
      unit='none',
      thresholds=g.thresholds([{ color: '#299c46', value: null }])
    ),
    g.statPanel(
      25,
      'Store Size',
      'nix_store_bytes',
      16, 3, 4,
      legend='store',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(80000000000, 140000000000)
    ),
    g.statPanel(
      26,
      'Closure Size',
      'nix_closure_bytes',
      20, 3, 4,
      legend='closure',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(1000000000000, 1500000000000)
    ),
    g.rowPanel(30, 'Pressure Signals — current avg10', 6),
    g.barGaugePanel(
      1,
      'CPU Pressure',
      'nix_pressure_cpu_avg10',
      'cpu',
      0, 7, 8,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.barGaugePanel(
      2,
      'IO Pressure',
      'nix_pressure_io_some_avg10',
      'io',
      8, 7, 8,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.barGaugePanel(
      3,
      'RAM Pressure',
      'nix_pressure_mem_some_avg10',
      'mem',
      16, 7, 8,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.pieChartPanel(
      40,
      'Pressure Breakdown',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 12, 8,
      h=6,
      unit='percent'
    ),
    g.timeseriesPanel(
      41,
      'Pressure History',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      8, 12, 16,
      h=6,
      unit='percent',
      fillOpacity=50,
      gradientMode='opacity',
      stackingMode='normal',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(10, 30),
      tooltip='multi',
      tooltipSort='desc',
      legendCalcs=['lastNotNull', 'max']
    ),
    g.rowPanel(31, 'Store and Build Trends', 18),
    g.timeseriesPanel(
      9,
      'Nix Store Size over Time',
      [
        { expr: 'nix_store_bytes', legend: 'total store' },
        { expr: 'nix_closure_bytes', legend: 'current closure' },
      ],
      0, 19, 15,
      h=8,
      unit='decbytes',
      fillOpacity=30,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('current closure', 'decbytes', fillOpacity=12),
      ]
    ),
    g.timeseriesPanel(
      11,
      'Rebuild Duration',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration s' }],
      15, 19, 9,
      h=8,
      unit='s',
      drawStyle='bars',
      lineWidth=0,
      fillOpacity=78,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(300, 900),
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max']
    ),
  ],
}
