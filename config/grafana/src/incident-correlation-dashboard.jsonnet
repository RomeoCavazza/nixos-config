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
    g.rowPanel(20, 'Incident strip', 2),
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
      thresholds=g.greenYellowRed(10, 30)
    ),
    g.statPanel(
      23,
      'Recent Errors',
      'sum(count_over_time({job="systemd-journal",component=~"display|build"} |~ "(?i)error|failed|panic" [15m]))',
      9, 3, 5,
      datasource='Loki',
      unit='none',
      thresholds=g.greenYellowRed(1, 5),
      mappings=[
        g.noDataMapping,
        g.rangeMapping(0, 0, 'Quiet', 'green', 1),
        g.rangeMapping(1, 4, 'Watch', 'yellow', 2),
        g.rangeMapping(5, 999999, 'Noisy', 'red', 3),
      ]
    ),
    g.gaugePanel(1, 'CPU Pressure', 'nix_pressure_cpu_avg10', 'cpu', 14, 3, 10),
    g.rowPanel(30, 'Pressure signals', 8),
    g.gaugePanel(2, 'IO Pressure', 'nix_pressure_io_some_avg10', 'io', 0, 9, 8),
    g.gaugePanel(3, 'Memory Pressure', 'nix_pressure_mem_some_avg10', 'mem', 8, 9, 8),
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
      unit='percent'
    ),
    g.rowPanel(31, 'Logs', 14),
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
      unit='percent'
    ),
    g.logsPanel(
      5,
      'Loki Journal (display/build)',
      '{job="systemd-journal",component=~"display|build"}',
      0, 22, 24, 10
    ),
  ],
}
