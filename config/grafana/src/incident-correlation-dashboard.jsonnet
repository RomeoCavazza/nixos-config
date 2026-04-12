local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Incident Correlation',
  'incident-correlation',
  '30s',
  'High-frequency pressure timeline linked to Loki logs for incident analysis.'
) {
  panels: [
    g.rowPanel(20, 'Incident Snapshot', 0),
    g.statPanel(
      21,
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      0, 1, 4,
      h=3,
      legend='pressure',
      unit='percent',
      decimals=1,
      thresholds=g.greenYellowRedHex(10, 30)
    ),
    g.statPanel(
      22,
      'Recent Errors',
      'sum(count_over_time({job="systemd-journal",component=~"display|build"} |~ "(?i)error|failed|panic" [15m]))',
      4, 1, 4,
      h=3,
      datasource='Loki',
      unit='none',
      thresholds=g.greenYellowRedHex(1, 5),
      mappings=[
        { type: 'special', options: { match: 'null', result: { text: 'Quiet', color: '#299c46', index: 0 } } },
        g.rangeMapping(0, 0, 'Quiet', '#299c46', 1),
        g.rangeMapping(1, 4, 'Watch', '#EAB839', 2),
        g.rangeMapping(5, 999999, 'Noisy', '#d44a3a', 3),
      ]
    ),
    g.statPanel(
      23,
      'CPU Pressure',
      'nix_pressure_cpu_avg10',
      8, 1, 4,
      h=3,
      legend='cpu',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.statPanel(
      24,
      'IO Pressure',
      'nix_pressure_io_some_avg10',
      12, 1, 4,
      h=3,
      legend='io',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.statPanel(
      25,
      'Memory Pressure',
      'nix_pressure_mem_some_avg10',
      16, 1, 4,
      h=3,
      legend='mem',
      unit='percent',
      decimals=2,
      thresholds=g.greenYellowRedHex(5, 10)
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
    g.rowPanel(30, 'Pressure Signal', 4),
    g.timeseriesPanel(
      31,
      'Pressure Timeline',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 5, 24,
      h=9,
      unit='percent',
      fillOpacity=12,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(10, 30),
      tooltip='multi',
      tooltipSort='desc',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max'],
      lineInterpolation='linear'
    ),
    g.stateTimelinePanel(
      32,
      'Incident Regime Timeline',
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
      0, 14, 24,
      h=3,
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
    g.rowPanel(40, 'Journal Correlation', 17),
    g.logsPanel(
      41,
      'Loki Journal (display/build)',
      '{job="systemd-journal",component=~"display|build"}',
      0, 18, 24, 12
    ),
  ],
}
