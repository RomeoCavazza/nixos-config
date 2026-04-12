local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Nix Efficiency',
  'nix-efficiency',
  '1m',
  'Trend view for freshness, generation debt, and rebuild cost.'
) {
  panels: [
    g.textPanel(
      0,
      'Efficiency lens',
      '**Use this view to spot drift.** It answers one question: how much retained state, age, footprint, and rebuild cost is accumulating over time?',
      0, 0, 24
    ),
    g.rowPanel(20, 'Drift Scorecard — current state', 2),
    g.statPanel(
      21,
      'Rendered',
      'time() * 1000',
      0, 3, 4,
      unit='dateTimeAsIso',
      colorMode='none',
      graphMode='none'
    ),
    g.gaugePanel(
      1,
      'Freshness Index',
      'nix_flake_lock_age_seconds / 86400',
      'days',
      4, 3, 5,
      h=5,
      unit='d',
      min=0,
      max=45,
      thresholds=g.greenYellowRedHex(15, 30)
    ),
    g.gaugePanel(
      2,
      'Generation Debt',
      'nix_generations_count',
      'retained generations',
      9, 3, 5,
      h=5,
      unit='none',
      min=0,
      max=40,
      thresholds=g.greenYellowRedHex(10, 20)
    ),
    g.statPanel(
      22,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      14, 3, 5,
      h=5,
      legend='duration',
      unit='s',
      thresholds=g.greenYellowRedHex(300, 900)
    ),
    g.statPanel(
      23,
      'Closure Paths',
      'nix_closure_paths',
      19, 3, 5,
      h=5,
      legend='paths',
      unit='none',
      thresholds=g.greenYellowRedHex(60000, 100000)
    ),
    g.rowPanel(30, 'Drift Trends — 6 h rolling', 8),
    g.timeseriesPanel(
      3,
      'Rebuild Duration Trend',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration s' }],
      0, 9, 12,
      h=7,
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
    g.timeseriesPanel(
      6,
      'Freshness and Generations',
      [
        { expr: 'nix_flake_lock_age_seconds / 86400', legend: 'lock age days' },
        { expr: 'nix_generations_count', legend: 'generations' },
      ],
      12, 9, 12,
      h=7,
      unit='none',
      fillOpacity=24,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('lock age days', 'd', axisPlacement='left', axisLabel='Days', fillOpacity=24),
        g.overrideUnitByName('generations', 'none', axisPlacement='right', axisLabel='Count', fillOpacity=10),
      ]
    ),
    g.rowPanel(31, 'Storage Footprint — store vs closure', 16),
    g.timeseriesPanel(
      4,
      'Store vs Closure Bytes',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      0, 17, 12,
      unit='decbytes',
      fillOpacity=28,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName('closure', 'decbytes', fillOpacity=10),
      ]
    ),
    g.timeseriesPanel(
      5,
      'Closure Volume vs Path Count',
      [
        { expr: 'nix_closure_bytes', legend: 'closure bytes' },
        { expr: 'nix_closure_paths', legend: 'closure paths' },
      ],
      12, 17, 12,
      unit='decbytes',
      axisLabel='Bytes',
      fillOpacity=26,
      gradientMode='opacity',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      overrides=[
        g.overrideUnitByName(
          'closure paths',
          'none',
          axisPlacement='right',
          axisLabel='Count',
          color={ mode: 'fixed', fixedColor: 'semi-dark-blue' },
          fillOpacity=8,
          lineWidth=1
        ),
      ]
    ),
    g.rowPanel(32, 'Drift Regime — threshold timeline', 25),
    g.stateTimelinePanel(
      33,
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
          legend: 'rebuild duration',
        },
      ],
      0, 26, 24,
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
