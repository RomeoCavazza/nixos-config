local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Incident Correlation',
  'incident-correlation',
  '30s',
  'High-frequency pressure timeline linked to Loki logs for incident analysis.'
) {
  panels: [
    g.rowPanel(10, 'Snapshot', 0),
    g.statPanel(
      11,
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      0, 1, 4, h=4,
      unit='percent',
      decimals=1,
      thresholds=g.greenYellowRed(10, 30)
    ),
    g.statPanel(
      12,
      'Recent Errors (15m)',
      'sum(count_over_time({job="systemd-journal",component=~"display|build"} |~ "(?i)error|failed|panic" [15m]))',
      4, 1, 4, h=4,
      datasource='Loki',
      unit='none',
      graphMode='none',
      thresholds=g.greenYellowRed(1, 5),
      mappings=[
        { type: 'special', options: { match: 'null', result: { text: 'Quiet', color: g.colors.ok, index: 0 } } },
        g.rangeMapping(0, 0, 'Quiet', g.colors.ok, 1),
        g.rangeMapping(1, 4, 'Watch', g.colors.warn, 2),
        g.rangeMapping(5, 999999, 'Noisy', g.colors.crit, 3),
      ]
    ),
    g.statPanel(
      13,
      'CPU Pressure',
      'nix_pressure_cpu_avg10',
      8, 1, 4, h=4,
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRed(5, 10)
    ),
    g.statPanel(
      14,
      'IO Pressure',
      'nix_pressure_io_some_avg10',
      12, 1, 4, h=4,
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRed(5, 10)
    ),
    g.statPanel(
      15,
      'Memory Pressure',
      'nix_pressure_mem_some_avg10',
      16, 1, 4, h=4,
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRed(5, 10)
    ),
    g.statPanel(
      16,
      'Last Rebuild',
      'nix_rebuild_duration_ms / 1000',
      20, 1, 4, h=4,
      unit='s',
      decimals=1,
      thresholds=g.greenYellowRed(300, 900)
    ),

    g.rowPanel(20, 'Pressure Signal', 5),
    g.timeseriesPanel(
      21,
      'Pressure Timeline',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 6, 24,
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
    g.stateTimelinePanel(
      22,
      'Incident Regime',
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
      0, 15, 24,
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

    g.rowPanel(30, 'Journal Correlation', 19),
    g.logsPanel(
      31,
      'Loki Journal (display / build)',
      '{job="systemd-journal",component=~"display|build"}',
      0, 20, 24, 12
    ),
  ],
}
