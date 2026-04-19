local g = import 'lib/dashboard.libsonnet';
local canonical = import 'nixos-compiled.jsonnet';

local railW = 5;
local graphX = railW;
local graphW = 24 - railW;
local graphH = 9;
local counterH = 5;
local summaryH = 12;

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
  'Temperature Sensors',
];

local railPanel(title, index) =
  panelByTitle(title) {
    id: 1301 + index,
    gridPos: { x: 0, y: summaryH + index * counterH, w: railW, h: counterH },
  };

local graphPanel(title, index) =
  panelByTitle(title) {
    id: 2301 + index,
    gridPos: { x: graphX, y: index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  panelByTitle('System Summary') {
    id: 1000,
    gridPos: { x: 0, y: 0, w: railW, h: summaryH },
  };

g.dashboard(
  'NixOS Incident Diagnostics',
  'incident-correlation',
  '10s',
  'Incident diagnostics view for journal events, thermal detail, disk latency, and network faults.',
  variables=[
    g.intervalVar('window', 'Growth window', ['3h', '12h', '24h', '7d'], '3h'),
  ],
) {
  timezone: 'browser',
  time: { from: 'now-3h', to: 'now' },
  panels:
    [summaryPanel]
    + std.mapWithIndex(function(index, title) railPanel(title, index), railTitles)
    + std.mapWithIndex(function(index, title) graphPanel(title, index), graphTitles),
}
