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
    g.rowPanel(20, 'Drift scorecard', 2),
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
      thresholds=g.greenYellowRed(15, 30)
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
      thresholds=g.greenYellowRed(10, 20)
    ),
    g.statPanel(
      22,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      14, 3, 5,
      h=5,
      legend='duration',
      unit='s',
      thresholds=g.greenYellowRed(300, 900)
    ),
    g.statPanel(
      23,
      'Closure Paths',
      'nix_closure_paths',
      19, 3, 5,
      h=5,
      legend='paths',
      unit='none',
      thresholds=g.greenYellowRed(60000, 100000)
    ),
    g.rowPanel(30, 'Drift trends', 8),
    g.timeseriesPanel(
      3,
      'Rebuild Duration Trend',
      [{ expr: 'nix_rebuild_duration_ms / 1000', legend: 'duration s' }],
      0, 9, 12,
      h=7,
      unit='s'
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
      overrides=[
        g.overrideUnitByName('lock age days', 'd', axisPlacement='left', axisLabel='Days'),
        g.overrideUnitByName('generations', 'none', axisPlacement='right', axisLabel='Count'),
      ]
    ),
    g.rowPanel(31, 'Storage footprint', 16),
    g.timeseriesPanel(
      4,
      'Store vs Closure Bytes',
      [
        { expr: 'nix_store_bytes', legend: 'store' },
        { expr: 'nix_closure_bytes', legend: 'closure' },
      ],
      0, 17, 12,
      unit='decbytes'
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
      overrides=[
        g.overrideUnitByName(
          'closure paths',
          'none',
          axisPlacement='right',
          axisLabel='Count',
          color={ mode: 'fixed', fixedColor: 'semi-dark-blue' }
        ),
      ]
    ),
  ],
}
