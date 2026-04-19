local g = import 'lib/dashboard.libsonnet';
local canonical = import 'nixos-compiled.jsonnet';

local railW = 5;
local graphX = railW;
local graphW = 24 - railW;
local graphH = 9;
local counterH = 5;
local summaryH = 6;

local panelByTitle(title) =
  std.filter(function(panel) std.get(panel, 'title', '') == title, canonical.panels)[0];

local railTitles = [
  'Journal Incidents',
  'Read Latency',
  'Write Latency',
  'Net Faults/s',
  'Critical Units',
  'Blocked',
  'Fullscreen Active',
  'Window Count',
];

local graphTitles = [
  'Incident Risk Timeline',
  'Journal Incident Logs',
  'Network Error and Drop Rate',
  'Disk I/O Throughput and Latency',
  'Resource Pressure Timeline',
  'Temperature Sensors',
  'NVIDIA GPU Metrics',
];

local railPanel(title, index) =
  panelByTitle(title) {
    id: 1301 + index,
    gridPos: { x: 0, y: summaryH + index * counterH, w: railW, h: counterH },
  };

local graphPanel(title, index) =
  panelByTitle(title) {
    id: 2301 + index,
    gridPos: { x: graphX, y: summaryH + index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  g.textPanel(
    1000,
    'Incident Diagnostics Summary',
    |||
      Diagnostic view correlating system logs with hardware signals for root-cause analysis.

      | Signal | Source | Role |
      | --- | --- | --- |
      | ![Loki](https://img.shields.io/badge/Loki-logs-8df4ec?style=flat-square&logo=grafana&logoColor=white&labelColor=101216) | `localhost:3100` | Centralized log ingestion |
      | ![Promtail](https://img.shields.io/badge/Promtail-journal-f6fbff?style=flat-square&logo=grafana&logoColor=white&labelColor=101216) | `journald` | Log labeling and shipping |
      | ![PSI](https://img.shields.io/badge/PSI-pressure-b48efa?style=flat-square&logo=prometheus&logoColor=white&labelColor=101216) | `/proc/pressure` | Kernel stall correlation |
      | ![Architecture](https://img.shields.io/badge/Architecture-Wiki-b48efa?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | [Wiki](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics) | Technical documentation mirror |
    |||,
    0, 0, 24, summaryH
  );

g.dashboard(
  'NixOS Incident Diagnostics',
  'incident-correlation',
  '10s',
  'Incident diagnostics view for journal events, thermal detail, disk latency, and network faults.',
  variables=[
    g.intervalVar('window', 'Growth window', ['3h', '6h', '12h', '24h', '7d'], '6h'),
  ],
) {
  timezone: 'browser',
  time: { from: 'now-6h', to: 'now' },
  panels:
    [summaryPanel]
    + std.mapWithIndex(function(index, title) railPanel(title, index), railTitles)
    + std.mapWithIndex(function(index, title) graphPanel(title, index), graphTitles),
}
