local g = import 'lib/dashboard.libsonnet';
local c = g.colors.mocha;

local journal = '{job="systemd-journal"}';
local incidentPattern = '(?i)(error|failed|panic|oom|segfault|denied|timeout|i/o error)';
local diskFilter = '{job="node",device!~"^(loop|ram|zram|dm-).*"}';
local netFilter = '{job="node",device!="lo"}';
local rateWindow = '5m';

local readLatency = 'rate(node_disk_read_time_seconds_total' + diskFilter + '[' + rateWindow + ']) / clamp_min(rate(node_disk_reads_completed_total' + diskFilter + '[' + rateWindow + ']), 0.001)';
local writeLatency = 'rate(node_disk_write_time_seconds_total' + diskFilter + '[' + rateWindow + ']) / clamp_min(rate(node_disk_writes_completed_total' + diskFilter + '[' + rateWindow + ']), 0.001)';
local netFaults = 'sum by (device) (rate(node_network_receive_errs_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_transmit_errs_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_receive_drop_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_transmit_drop_total' + netFilter + '[' + rateWindow + ']))';

local diskReadSeverity = '(' + readLatency + ' > bool 0.02) + (' + readLatency + ' > bool 0.10)';
local diskWriteSeverity = '(' + writeLatency + ' > bool 0.02) + (' + writeLatency + ' > bool 0.10)';
local netSeverity = '(' + netFaults + ' > bool 0) + (' + netFaults + ' > bool 0.1)';

local hiddenTimeAxis = {
  matcher: { id: 'byType', options: 'time' },
  properties: [g.propAxisPlacement('hidden')],
};

local incidentMappings = [
  g.valueMapping(0, 'clean', c.green, 0),
  g.valueMapping(1, 'watch', c.yellow, 1),
  g.valueMapping(2, 'critical', c.red, 2),
  g.noDataMapping,
];

g.dashboard(
  'NixOS Black Box',
  'nixos-black-box',
  '10s',
  'Incident and IO diagnostics: semantized journald events, disk latency, and network faults.'
) {
  time: { from: 'now-6h', to: 'now' },
  panels: [
    g.rowPanel(1, 'Incident Overview', 0),

    g.statPanel(
      2,
      'Journal Incidents',
      'sum(count_over_time(' + journal + ' |~ "' + incidentPattern + '" [15m]))',
      0, 1, 4, 4,
      datasource='Loki',
      unit='none',
      decimals=0,
      thresholds=g.greenYellowRed(3, 10),
      colorMode='background',
      graphMode='none'
    ),
    g.statPanel(
      3,
      'Build Log Faults',
      'sum(count_over_time({job="systemd-journal",component="build"} |~ "' + incidentPattern + '" [15m]))',
      4, 1, 4, 4,
      datasource='Loki',
      unit='none',
      decimals=0,
      thresholds=g.greenYellowRed(1, 4),
      colorMode='background',
      graphMode='none'
    ),
    g.statPanel(4, 'Max Read Latency', 'max(' + readLatency + ')', 8, 1, 4, 4, unit='s', decimals=4, thresholds=g.greenYellowRed(0.02, 0.10)),
    g.statPanel(5, 'Max Write Latency', 'max(' + writeLatency + ')', 12, 1, 4, 4, unit='s', decimals=4, thresholds=g.greenYellowRed(0.02, 0.10)),
    g.statPanel(6, 'Net Faults/s', 'sum(' + netFaults + ')', 16, 1, 4, 4, unit='ops', decimals=3, thresholds=g.greenYellowRed(0.01, 0.10)),
    g.statPanel(
      7,
      'Critical Units',
      'sum(count_over_time({job="systemd-journal"} |= "Failed" [15m]))',
      20, 1, 4, 4,
      datasource='Loki',
      unit='none',
      decimals=0,
      thresholds=g.greenYellowRed(1, 3),
      colorMode='background',
      graphMode='none'
    ),

    g.rowPanel(10, 'Timeline Lanes', 5),

    g.stateTimelinePanel(
      11,
      'Incident Lanes',
      [
        { expr: diskReadSeverity, legend: 'disk read {{device}}' },
        { expr: diskWriteSeverity, legend: 'disk write {{device}}' },
        { expr: netSeverity, legend: 'net {{device}}' },
      ],
      0, 6, 24, 5,
      mappings=incidentMappings,
      thresholds=g.thresholds([
        { color: c.green, value: null },
        { color: c.yellow, value: 1 },
        { color: c.red, value: 2 },
      ]),
      showLegend=true,
      showValue='never',
      rowHeight=0.82
    ),

    g.rowPanel(20, 'IO And Network', 11),

    g.timeseriesPanel(
      21,
      'Disk Operation Latency',
      [
        { expr: readLatency, legend: 'read {{device}}' },
        { expr: writeLatency, legend: 'write {{device}}' },
      ],
      0, 12, 8, 7,
      unit='s',
      fillOpacity=10,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(0.02, 0.10),
      overrides=[
        g.overrideByRegex('read .*', [g.propColor(c.teal), g.propLineWidth(2)]),
        g.overrideByRegex('write .*', [g.propColor(c.peach), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.timeseriesPanel(
      22,
      'Disk Throughput',
      [
        { expr: 'rate(node_disk_read_bytes_total' + diskFilter + '[' + rateWindow + '])', legend: 'read {{device}}' },
        { expr: 'rate(node_disk_written_bytes_total' + diskFilter + '[' + rateWindow + '])', legend: 'write {{device}}' },
      ],
      8, 12, 8, 7,
      unit='Bps',
      fillOpacity=20,
      gradientMode='opacity',
      overrides=[
        g.overrideByRegex('read .*', [g.propColor(c.sky), g.propFillOpacity(18)]),
        g.overrideByRegex('write .*', [g.propColor(c.blue), g.propFillOpacity(18), { id: 'custom.transform', value: 'negative-Y' }]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.timeseriesPanel(
      23,
      'Network Faults',
      [
        { expr: 'rate(node_network_receive_errs_total' + netFilter + '[' + rateWindow + '])', legend: 'rx errors {{device}}' },
        { expr: 'rate(node_network_transmit_errs_total' + netFilter + '[' + rateWindow + '])', legend: 'tx errors {{device}}' },
        { expr: 'rate(node_network_receive_drop_total' + netFilter + '[' + rateWindow + '])', legend: 'rx drops {{device}}' },
        { expr: 'rate(node_network_transmit_drop_total' + netFilter + '[' + rateWindow + '])', legend: 'tx drops {{device}}' },
      ],
      16, 12, 8, 7,
      unit='ops',
      fillOpacity=18,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(0.01, 0.10),
      overrides=[
        g.overrideByRegex('rx errors .*', [g.propColor(c.red), g.propLineWidth(2)]),
        g.overrideByRegex('tx errors .*', [g.propColor(c.maroon), g.propLineWidth(2)]),
        g.overrideByRegex('rx drops .*', [g.propColor(c.yellow)]),
        g.overrideByRegex('tx drops .*', [g.propColor(c.peach)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.rowPanel(30, 'Journald', 19),

    g.multiTargetTimeseries(
      31,
      'Journal Semantic Events',
      [
        g.lokiRateTarget('{job="systemd-journal",component="system"}', incidentPattern, '$__interval', 'system', 'A'),
        g.lokiRateTarget('{job="systemd-journal",component="build"}', incidentPattern, '$__interval', 'build', 'B'),
        g.lokiRateTarget('{job="systemd-journal",component="display"}', incidentPattern, '$__interval', 'display', 'C'),
      ],
      0, 20, 8, 8,
      unit='ops',
      fillOpacity=24,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(1, 5),
      overrides=[
        g.overrideByName('system', [g.propColor(c.blue), g.propLineWidth(2)]),
        g.overrideByName('build', [g.propColor(c.peach), g.propLineWidth(2)]),
        g.overrideByName('display', [g.propColor(c.mauve), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.logsPanel(
      32,
      'Journald Incident Feed',
      journal + ' |~ "' + incidentPattern + '"',
      8, 20, 16, 8
    ),
  ],
}
