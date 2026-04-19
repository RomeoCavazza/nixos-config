local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Nix Efficiency',
  'nix-efficiency',
  '1m',
  'Trend view for freshness, generation debt, and rebuild cost.'
) {
  panels: [
    g.rowPanel(10, 'Drift Snapshot', 0),
    g.statPanel(
      11,
      'Flake Age',
      'nix_flake_lock_age_seconds / 86400',
      0, 1, 4, h=4,
      unit='d',
      decimals=1,
      thresholds=g.greenYellowRed(15, 30)
    ),
    g.statPanel(
      12,
      'Generations Kept',
      'nix_generations_count',
      4, 1, 4, h=4,
      unit='none',
      thresholds=g.greenYellowRed(10, 20)
    ),
    g.statPanel(
      13,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      8, 1, 4, h=4,
      unit='s',
      decimals=1,
      thresholds=g.greenYellowRed(300, 900)
    ),
    g.statPanel(
      14,
      'Closure Paths',
      'nix_closure_paths',
      12, 1, 4, h=4,
      unit='none',
      thresholds=g.greenYellowRed(60000, 100000)
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

    g.rowPanel(20, 'Freshness and Growth', 5),
    g.timeseriesPanel(
      21,
      'Flake Age vs Generations',
      [
        { expr: 'nix_flake_lock_age_seconds / 86400', legend: 'flake age (days)' },
        { expr: 'nix_generations_count', legend: 'generations' },
      ],
      0, 6, 12,
      h=9,
      fillOpacity=14,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('flake age (days)', 'd', axisPlacement='left', axisLabel='Days'),
        g.overrideUnitByName('generations', 'none', axisPlacement='right', axisLabel='Count'),
      ]
    ),
    g.timeseriesPanel(
      22,
      'Store vs Closure Bytes',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      12, 6, 12,
      h=9,
      unit='decbytes',
      fillOpacity=14,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.rowPanel(30, 'Build Cost', 15),
    g.timeseriesPanel(
      31,
      'Rebuild Duration',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration' }],
      0, 16, 16,
      h=9,
      unit='s',
      fillOpacity=16,
      gradientMode='opacity',
      thresholdsStyle='dashed',
      thresholds=g.greenYellowRed(300, 900),
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'mean', 'max']
    ),
    g.barGaugePanel(
      32,
      'Path Density',
      [
        { expr: 'nix_store_paths', legend: 'store paths' },
        { expr: 'nix_closure_paths', legend: 'closure paths' },
      ],
      16, 16, 8,
      h=9,
      unit='none',
      min=0,
      max=300000,
      orientation='horizontal',
      displayMode='gradient',
      thresholds=g.greenYellowRed(200000, 300000)
    ),

    g.rowPanel(40, 'Drift Regime', 25),
    g.stateTimelinePanel(
      41,
      'Freshness / Generation / Rebuild',
      [
        {
          expr: 'clamp_max((nix_flake_lock_age_seconds / 86400 >= bool 15) + (nix_flake_lock_age_seconds / 86400 >= bool 30), 2)',
          legend: 'flake age',
        },
        {
          expr: 'clamp_max((nix_generations_count >= bool 10) + (nix_generations_count >= bool 20), 2)',
          legend: 'generations',
        },
        {
          expr: 'clamp_max((nix_rebuild_duration_ms / 1000 >= bool 300) + (nix_rebuild_duration_ms / 1000 >= bool 900), 2)',
          legend: 'rebuild',
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
