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
  'Uptime',
  'CPU Busy',
  'RAM Used',
  'Load/Core',
  'CPU PSI',
  'Memory PSI',
  'Max Temp',
  'Running',
  'Ctx/s',
];

local graphTitles = [
  'CPU Utilization by Mode',
  'Memory Usage Breakdown',
  'Load Average vs CPU Capacity',
  'Resource Pressure Heatmap',
  'Resource Pressure Timeline',
];

local railPanel(title, index) =
  panelByTitle(title) {
    id: 1101 + index,
    gridPos: { x: 0, y: summaryH + index * counterH, w: railW, h: counterH },
  };

local graphPanel(title, index) =
  panelByTitle(title) {
    id: 2101 + index,
    gridPos: { x: graphX, y: index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  panelByTitle('System Summary') {
    id: 1000,
    gridPos: { x: 0, y: 0, w: railW, h: summaryH },
  };

g.dashboard(
  'NixOS Metrics',
  'nixos-metrics',
  '10s',
  'Host performance view for CPU, memory, load, pressure, thermals, and GPU telemetry.'
) {
  timezone: 'browser',
  time: { from: 'now-3h', to: 'now' },
  panels:
    [summaryPanel]
    + std.mapWithIndex(function(index, title) railPanel(title, index), railTitles)
    + std.mapWithIndex(function(index, title) graphPanel(title, index), graphTitles),
}
