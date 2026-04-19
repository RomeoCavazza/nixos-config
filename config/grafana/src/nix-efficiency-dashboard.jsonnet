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
  'Resource Pressure Timeline',
  'Temperature Sensors',
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
    gridPos: { x: graphX, y: summaryH + index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  g.textPanel(
    1000,
    'Nix Efficiency Summary',
    |||
      Optimization view for tracking store growth, input freshness, and rebuild costs.

      | Metric | Target | Purpose |
      | --- | --- | --- |
      | ![Nix Store](https://img.shields.io/badge/Nix_Store-growth-70efe5?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | `/nix/store` | Footprint and path tracking |
      | ![Flake](https://img.shields.io/badge/Flake-freshness-b48efa?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | `flake.lock` | Input drift monitoring |
      | ![Rebuild](https://img.shields.io/badge/Rebuild-cost-f5c2e7?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | `systemd` | Build duration and outcome |
      | ![Architecture](https://img.shields.io/badge/Architecture-Wiki-b48efa?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | [Wiki](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics) | Technical documentation mirror |
    |||,
    0, 0, 24, summaryH
  );

g.dashboard(
  'Nix Efficiency',
  'nix-efficiency',
  '10s',
  'Store and rebuild view for closure growth, generations, rebuild activity, and pressure signals.',
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
