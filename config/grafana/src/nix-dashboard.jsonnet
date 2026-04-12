local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'NixOS Metrics',
  'nixos-metrics',
  '30s',
  'Live health view for Nix pressure, rebuild cost, and store growth.'
) {
  panels: [
    g.rowPanel(20, 'System Health', 0),
    g.statPanel(
      21,
      'Prometheus Data Age',
      'time() - max(timestamp(nix_store_bytes))',
      0, 1, 4,
      h=3,
      unit='s',
      decimals=0,
      thresholds=g.greenYellowRedHex(60, 300),
      mappings=[g.noDataMapping]
    ),
    g.statPanel(
      22,
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      4, 1, 4,
      h=3,
      legend='pressure',
      unit='percent',
      decimals=1,
      min=0,
      max=100,
      thresholds=g.greenYellowRedHex(10, 30)
    ),
    g.statPanel(
      23,
      'Generation',
      'nix_generation',
      8, 1, 4,
      h=3,
      legend='generation',
      unit='none',
      thresholds=g.thresholds([{ color: g.colors.aqua, value: null }])
    ),
    g.statPanel(
      24,
      'Store Size',
      'nix_store_bytes',
      12, 1, 4,
      h=3,
      legend='store',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(80000000000, 140000000000)
    ),
    g.statPanel(
      25,
      'Closure Size',
      'nix_closure_bytes',
      16, 1, 4,
      h=3,
      legend='closure',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(1000000000000, 1500000000000)
    ),
    g.statPanel(
      26,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      20, 1, 4,
      h=3,
      legend='duration',
      unit='s',
      thresholds=g.greenYellowRedHex(300, 900)
    ),
    g.rowPanel(30, 'Pressure', 4),
    g.timeseriesPanel(
      31,
      'CPU, IO, and Memory Pressure',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 5, 18,
      h=10,
      unit='percent',
      fillOpacity=12,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(10, 30),
      tooltip='multi',
      tooltipSort='desc',
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max'],
      lineInterpolation='linear',
      overrides=[
        g.overrideUnitByName('CPU', 'percent', color=g.fixedColor(g.colors.aqua), fillOpacity=12),
        g.overrideUnitByName('IO', 'percent', color=g.fixedColor(g.colors.cyan), fillOpacity=10),
        g.overrideUnitByName('MEM', 'percent', color=g.fixedColor(g.colors.lavender), fillOpacity=8),
      ]
    ),
    g.statPanel(
      32,
      'CPU Pressure',
      'nix_pressure_cpu_avg10',
      18, 5, 6,
      h=3,
      legend='cpu',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.statPanel(
      33,
      'IO Pressure',
      'nix_pressure_io_some_avg10',
      18, 8, 6,
      h=3,
      legend='io',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.statPanel(
      34,
      'Memory Pressure',
      'nix_pressure_mem_some_avg10',
      18, 11, 6,
      h=4,
      legend='mem',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.rowPanel(40, 'Storage and Build', 15),
    g.timeseriesPanel(
      41,
      'Store vs Current Closure',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      0, 16, 16,
      h=9,
      unit='decbytes',
      fillOpacity=16,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('store', 'decbytes', color=g.fixedColor(g.colors.ice), fillOpacity=14),
        g.overrideUnitByName('closure', 'decbytes', color=g.fixedColor(g.colors.sapphire), fillOpacity=8),
      ]
    ),
    g.statPanel(
      42,
      'Store Paths',
      'nix_store_paths',
      16, 16, 4,
      h=4,
      legend='paths',
      unit='none',
      thresholds=g.greenYellowRedHex(200000, 300000)
    ),
    g.statPanel(
      43,
      'Closure Paths',
      'nix_closure_paths',
      20, 16, 4,
      h=4,
      legend='paths',
      unit='none',
      thresholds=g.greenYellowRedHex(60000, 100000)
    ),
    g.statPanel(
      44,
      'Generations Kept',
      'nix_generations_count',
      16, 20, 4,
      h=5,
      legend='generations',
      unit='none',
      thresholds=g.greenYellowRedHex(10, 20)
    ),
    g.statPanel(
      45,
      'Build Health',
      'nix_rebuild_success',
      20, 20, 4,
      h=5,
      legend='success',
      unit='none',
      thresholds=g.thresholds([
        { color: g.colors.rose, value: null },
        { color: g.colors.aqua, value: 1 },
      ]),
      mappings=[
        g.rangeMapping(0, 0, 'Failed', g.colors.rose, 0),
        g.rangeMapping(1, 1, 'OK', g.colors.aqua, 1),
        g.noDataMapping,
      ]
    ),
    g.rowPanel(50, 'Pressure Regime', 25),
    g.stateTimelinePanel(
      51,
      'CPU, IO, and Memory Regimes',
      [
        {
          expr: 'clamp_max((nix_pressure_cpu_avg10 >= bool 10) + (nix_pressure_cpu_avg10 >= bool 30), 2)',
          legend: 'CPU',
        },
        {
          expr: 'clamp_max((nix_pressure_io_some_avg10 >= bool 10) + (nix_pressure_io_some_avg10 >= bool 30), 2)',
          legend: 'IO',
        },
        {
          expr: 'clamp_max((nix_pressure_mem_some_avg10 >= bool 10) + (nix_pressure_mem_some_avg10 >= bool 30), 2)',
          legend: 'MEM',
        },
      ],
      0, 26, 24,
      h=4,
      mappings=[
        {
          type: 'value',
          options: {
            '0': { text: 'Good', color: g.colors.aqua, index: 0 },
            '1': { text: 'Watch', color: g.colors.sapphire, index: 1 },
            '2': { text: 'Critical', color: g.colors.mauve, index: 2 },
          },
        },
      ]
    ),
  ],
}
