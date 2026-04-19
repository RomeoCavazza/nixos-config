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
  'Flake Lock Age',
  'Store Used',
  'Store Free',
  'Store Fill',
  'Closure Size',
  'Closure Paths',
  'Generations',
  'IO PSI',
];

local graphTitles = [
  'Rebuild Activity',
  'Nix Store Growth',
  'Store Path Retention Flamegraph',
  'Process Scheduler Activity',
  'NVIDIA GPU Metrics',
];

local railPanel(title, index) =
  panelByTitle(title) {
    id: 1201 + index,
    gridPos: { x: 0, y: summaryH + index * counterH, w: railW, h: counterH },
  };

local graphPanel(title, index) =
  panelByTitle(title) {
    id: 2201 + index,
    gridPos: { x: graphX, y: index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  panelByTitle('System Summary') {
    id: 1000,
    gridPos: { x: 0, y: 0, w: railW, h: summaryH },
  };

g.dashboard(
  'Nix Efficiency',
  'nix-efficiency',
  '10s',
  'Store and rebuild view for closure growth, generations, rebuild activity, and pressure signals.',
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
