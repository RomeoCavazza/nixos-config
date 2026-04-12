local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Nix Efficiency',
  'nix-efficiency',
  '1m',
  'Trend view for freshness, generation debt, and rebuild cost.'
) {
  panels: [
    g.rowPanel(20, 'Drift Health', 0),
    g.statPanel(
      21,
      'Flake Age',
      'nix_flake_lock_age_seconds / 86400',
      0, 1, 4,
      h=3,
      legend='days',
      unit='d',
      decimals=1,
      thresholds=g.greenYellowRedHex(15, 30)
    ),
    g.statPanel(
      22,
      'Generations Kept',
      'nix_generations_count',
      4, 1, 4,
      h=3,
      legend='generations',
      unit='none',
      thresholds=g.greenYellowRedHex(10, 20)
    ),
    g.statPanel(
      23,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      8, 1, 4,
      h=3,
      legend='duration',
      unit='s',
      thresholds=g.greenYellowRedHex(300, 900)
    ),
    g.statPanel(
      24,
      'Closure Paths',
      'nix_closure_paths',
      12, 1, 4,
      h=3,
      legend='paths',
      unit='none',
      thresholds=g.greenYellowRedHex(60000, 100000)
    ),
    g.statPanel(
      25,
      'Store Size',
      'nix_store_bytes',
      16, 1, 4,
      h=3,
      legend='store',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(80000000000, 140000000000)
    ),
    g.statPanel(
      26,
      'Closure Size',
      'nix_closure_bytes',
      20, 1, 4,
      h=3,
      legend='closure',
      unit='decbytes',
      thresholds=g.greenYellowRedHex(1000000000000, 1500000000000)
    ),
    g.rowPanel(30, 'Drift Trends', 4),
    g.timeseriesPanel(
      31,
      'Freshness and Generations',
      [
        { expr: 'nix_flake_lock_age_seconds / 86400', legend: 'flake age' },
        { expr: 'nix_generations_count', legend: 'generations' },
      ],
      0, 5, 12,
      h=8,
      unit='none',
      fillOpacity=12,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      lineInterpolation='linear',
      overrides=[
        g.overrideUnitByName('flake age', 'd', axisPlacement='left', axisLabel='Days', fillOpacity=12),
        g.overrideUnitByName('generations', 'none', axisPlacement='right', axisLabel='Count', fillOpacity=6),
      ]
    ),
    g.timeseriesPanel(
      32,
      'Store vs Closure Bytes',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      12, 5, 12,
      h=8,
      unit='decbytes',
      fillOpacity=12,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('closure', 'decbytes', fillOpacity=6),
      ]
    ),
    g.rowPanel(40, 'Closure and Build Shape', 13),
    g.timeseriesPanel(
      41,
      'Closure Volume vs Path Count',
      [
        { expr: 'nix_closure_bytes', legend: 'closure bytes' },
        { expr: 'nix_closure_paths', legend: 'closure paths' },
      ],
      0, 14, 16,
      h=8,
      unit='decbytes',
      axisLabel='Bytes',
      fillOpacity=12,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      lineInterpolation='linear',
      overrides=[
        g.overrideUnitByName(
          'closure paths',
          'none',
          axisPlacement='right',
          axisLabel='Count',
          color={ mode: 'fixed', fixedColor: 'semi-dark-blue' },
          fillOpacity=4,
          lineWidth=1
        ),
      ]
    ),
    g.timeseriesPanel(
      42,
      'Rebuild Duration',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration' }],
      16, 14, 8,
      h=8,
      unit='s',
      fillOpacity=10,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(300, 900),
      legendDisplayMode='table',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull', 'max'],
      lineInterpolation='linear'
    ),
    g.rowPanel(50, 'Drift Regime', 22),
    g.stateTimelinePanel(
      51,
      'Freshness, Generation, and Rebuild Regimes',
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
      0, 23, 24,
      h=4,
      mappings=[
        {
          type: 'value',
          options: {
            '0': { text: 'Good', color: '#299c46', index: 0 },
            '1': { text: 'Watch', color: '#EAB839', index: 1 },
            '2': { text: 'Critical', color: '#d44a3a', index: 2 },
          },
        },
      ]
    ),
  ],
}
