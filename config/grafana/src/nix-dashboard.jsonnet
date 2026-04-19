local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'NixOS Metrics',
  'nixos-metrics',
  '30s',
  'Live health view for Nix pressure, rebuild cost, and store growth.'
) {
  panels: [
    g.rowPanel(10, 'Snapshot', 0),
    g.statPanel(
      11,
      'Data Age',
      'time() - max(timestamp(nix_store_bytes))',
      0, 1, 4, h=4,
      unit='s',
      decimals=0,
      graphMode='none',
      thresholds=g.greenYellowRed(60, 300),
      mappings=[g.noDataMapping]
    ),
    g.statPanel(
      12,
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      4, 1, 4, h=4,
      unit='percent',
      decimals=1,
      min=0,
      max=100,
      thresholds=g.greenYellowRed(10, 30)
    ),
    g.statPanel(
      13,
      'Generation',
      'nix_generation',
      8, 1, 4, h=4,
      unit='none',
      graphMode='none',
      thresholds=g.thresholds([{ color: g.colors.info, value: null }])
    ),
    g.statPanel(
      14,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      12, 1, 4, h=4,
      unit='s',
      decimals=1,
      thresholds=g.greenYellowRed(300, 900)
    ),
    g.statPanel(
      15,
      'Store Size',
      'nix_store_bytes',
      16, 1, 4, h=4,
      unit='decbytes',
      decimals=1,
      thresholds=g.greenYellowRed(80000000000, 140000000000)
    ),
    g.statPanel(
      16,
      'Closure Size',
      'nix_closure_bytes',
      20, 1, 4, h=4,
      unit='decbytes',
      decimals=1,
      thresholds=g.greenYellowRed(1000000000000, 1500000000000)
    ),

    g.rowPanel(20, 'System Pressure', 5),
    g.timeseriesPanel(
      21,
      'CPU / IO / Memory Pressure',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 6, 16,
      h=9,
      unit='percent',
      fillOpacity=16,
      gradientMode='opacity',
      thresholdsStyle='dashed',
      thresholds=g.greenYellowRed(10, 30),
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'mean', 'max']
    ),
    g.barGaugePanel(
      22,
      'Current Pressure',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      16, 6, 8,
      h=9,
      unit='percent',
      min=0,
      max=100,
      orientation='vertical',
      displayMode='gradient',
      thresholds=g.greenYellowRed(10, 30)
    ),

    g.rowPanel(30, 'Storage and Build', 15),
    g.timeseriesPanel(
      31,
      'Store vs Closure',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      0, 16, 16,
      h=9,
      unit='decbytes',
      fillOpacity=14,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max']
    ),
    g.statPanel(
      32,
      'Store Paths',
      'nix_store_paths',
      16, 16, 4, h=4,
      unit='none',
      thresholds=g.greenYellowRed(200000, 300000)
    ),
    g.statPanel(
      33,
      'Closure Paths',
      'nix_closure_paths',
      20, 16, 4, h=4,
      unit='none',
      thresholds=g.greenYellowRed(60000, 100000)
    ),
    g.statPanel(
      34,
      'Generations Kept',
      'nix_generations_count',
      16, 20, 4, h=5,
      unit='none',
      thresholds=g.greenYellowRed(10, 20)
    ),
    g.statPanel(
      35,
      'Build Health',
      'nix_rebuild_success',
      20, 20, 4, h=5,
      unit='none',
      graphMode='none',
      thresholds=g.thresholds([
        { color: g.colors.crit, value: null },
        { color: g.colors.ok, value: 1 },
      ]),
      mappings=[
        g.rangeMapping(0, 0, 'Failed', g.colors.crit, 0),
        g.rangeMapping(1, 1, 'OK', g.colors.ok, 1),
        g.noDataMapping,
      ]
    ),

    g.rowPanel(40, 'Pressure Regime', 25),
    g.stateTimelinePanel(
      41,
      'CPU / IO / Memory Regime',
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
            '0': { text: 'Good', color: g.colors.ok, index: 0 },
            '1': { text: 'Watch', color: g.colors.warn, index: 1 },
            '2': { text: 'Critical', color: g.colors.crit, index: 2 },
          },
        },
      ]
    ),
  ],
}
