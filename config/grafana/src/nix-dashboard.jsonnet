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
  'Temperature Sensors',
  'NVIDIA GPU Metrics',
];

local railPanel(title, index) =
  panelByTitle(title) {
    id: 1101 + index,
    gridPos: { x: 0, y: summaryH + index * counterH, w: railW, h: counterH },
  };

local graphPanel(title, index) =
  panelByTitle(title) {
    id: 2101 + index,
    gridPos: { x: graphX, y: summaryH + index * graphH, w: graphW, h: graphH },
  };

local summaryPanel =
  g.textPanel(
    1000,
    'System Cockpit Summary',
    |||
      Operational view for monitoring hardware health, system saturation, and hardware telemetry.

      | Component | Endpoint | Role |
      | --- | --- | --- |
      | ![Prometheus](https://img.shields.io/badge/Prometheus-metrics-b48efa?style=flat-square&logo=prometheus&logoColor=white&labelColor=101216) | `localhost:9090` | Metrics TSDB and query engine |
      | ![Node Exporter](https://img.shields.io/badge/Node_Exporter-host-70efe5?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | `localhost:9100` | Host metrics plus textfile collector |
      | ![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU-76b900?style=flat-square&logo=nvidia&logoColor=white&labelColor=101216) | `nvidia-smi` | VRAM and Power telemetry |
      | ![Architecture](https://img.shields.io/badge/Architecture-Wiki-b48efa?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | [Wiki](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics) | Technical documentation mirror |
    |||,
    0, 0, 24, summaryH
  );

g.dashboard(
  'NixOS Metrics',
  'nixos-metrics',
  '10s',
  'Host performance view for CPU, memory, load, pressure, thermals, and GPU telemetry.',
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
