local g = import 'lib/dashboard.libsonnet';

g.dashboard(
  'Incident Correlation',
  'incident-correlation',
  '30s',
  'High-frequency pressure timeline linked to Loki logs for incident analysis.'
) {
  panels: [
    g.textPanel(
      0,
      'Incident context',
      '**This dashboard is for correlation, not overview.** Start with pressure, then move immediately to logs when something spikes.',
      0, 0, 24
    ),
    g.rowPanel(20, 'Incident KPIs — snapshot', 2),
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
      'Max Pressure',
      'max({__name__=~"nix_pressure_cpu_avg10|nix_pressure_io_some_avg10|nix_pressure_mem_some_avg10"})',
      4, 3, 5,
      legend='pressure',
      unit='percent',
      decimals=1,
      thresholds=g.greenYellowRedHex(10, 30)
    ),
    g.statPanel(
      23,
      'Recent Errors',
      'sum(count_over_time({job="systemd-journal",component=~"display|build"} |~ "(?i)error|failed|panic" [15m]))',
      9, 3, 5,
      datasource='Loki',
      unit='none',
      thresholds=g.greenYellowRedHex(1, 5),
      mappings=[
        // Loki returns null (no series) when no streams match — treat as Quiet
        { type: 'special', options: { match: 'null', result: { text: 'Quiet', color: '#299c46', index: 0 } } },
        g.rangeMapping(0, 0, 'Quiet', '#299c46', 1),
        g.rangeMapping(1, 4, 'Watch', '#EAB839', 2),
        g.rangeMapping(5, 999999, 'Noisy', '#d44a3a', 3),
      ]
    ),
    g.barGaugePanel(
      1,
      'CPU Pressure',
      'nix_pressure_cpu_avg10',
      'cpu',
      14, 3, 10,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.rowPanel(30, 'Pressure Signals — avg10 breakdown', 8),
    g.barGaugePanel(
      2,
      'IO Pressure',
      'nix_pressure_io_some_avg10',
      'io',
      0, 9, 8,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.barGaugePanel(
      3,
      'Memory Pressure',
      'nix_pressure_mem_some_avg10',
      'mem',
      8, 9, 8,
      max=15,
      thresholds=g.greenYellowRedHex(5, 10)
    ),
    g.timeseriesPanel(
      4,
      'Pressure Timeline',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      16, 9, 8,
      h=5,
      unit='percent',
      fillOpacity=50,
      gradientMode='opacity',
      stackingMode='normal',
      thresholdsStyle='line',
      thresholds=g.greenYellowRedHex(10, 30),
      tooltip='multi'
    ),
    g.rowPanel(31, 'Log Correlation — journal stream', 14),
    g.timeseriesPanel(
      6,
      'Pressure Timeline Detail',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'MEM' },
      ],
      0, 15, 24,
      h=7,
      unit='percent',
      fillOpacity=55,
      gradientMode='opacity',
      stackingMode='normal',
      thresholdsStyle='area',
      thresholds=g.greenYellowRedHex(10, 30),
      tooltip='multi',
      tooltipSort='desc',
      legendDisplayMode='table',
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),
    g.stateTimelinePanel(
      7,
      'Incident Regime Timeline',
      [
        {
          expr: 'clamp_max((nix_pressure_cpu_avg10 >= bool 10) + (nix_pressure_cpu_avg10 >= bool 30), 2)',
          legend: 'CPU regime',
        },
        {
          expr: 'clamp_max((nix_pressure_io_some_avg10 >= bool 10) + (nix_pressure_io_some_avg10 >= bool 30), 2)',
          legend: 'IO regime',
        },
        {
          expr: 'clamp_max((nix_pressure_mem_some_avg10 >= bool 10) + (nix_pressure_mem_some_avg10 >= bool 30), 2)',
          legend: 'MEM regime',
        },
      ],
      0, 22, 24,
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
    g.logsPanel(
      5,
      'Loki Journal (display/build)',
      '{job="systemd-journal",component=~"display|build"}',
      0, 26, 24, 10
    ),
  ],
}
