local g = import 'lib/dashboard.libsonnet';
local c = g.colors.mocha;

local rateWindow = '5m';
local cpuBusy = '100 * (1 - avg(rate(node_cpu_seconds_total{job="node",mode="idle"}[' + rateWindow + '])))';
local cpuCores = 'scalar(count(count by (cpu) (node_cpu_seconds_total{job="node",mode="idle"})))';
local memUsedPercent = '100 * (1 - node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"})';
local loadPerCore = 'node_load1{job="node"} / ' + cpuCores;

local hiddenTimeAxis = {
  matcher: { id: 'byType', options: 'time' },
  properties: [g.propAxisPlacement('hidden')],
};

g.dashboard(
  'NixOS Engine',
  'nixos-engine',
  '5s',
  'Immediate host pulse: CPU, RAM, load, thermals, and PSI pressure.'
) {
  time: { from: 'now-1h', to: 'now' },
  panels: [
    g.rowPanel(1, 'Pulse', 0),

    g.statPanel(2, 'Uptime', 'time() - node_boot_time_seconds{job="node"}', 0, 1, 4, 4, unit='s', decimals=0, colorMode='value', graphMode='none'),
    g.statPanel(3, 'CPU Busy', cpuBusy, 4, 1, 4, 4, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(70, 90)),
    g.statPanel(4, 'RAM Used', memUsedPercent, 8, 1, 4, 4, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(75, 90)),
    g.statPanel(5, 'Load/Core', loadPerCore, 12, 1, 4, 4, unit='short', decimals=2, thresholds=g.greenYellowRed(0.8, 1.5)),
    g.statPanel(6, 'CPU PSI', 'nix_pressure_cpu_avg10', 16, 1, 4, 4, unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(2, 5, 15, 30)),
    g.statPanel(7, 'Memory PSI', 'nix_pressure_mem_some_avg10', 20, 1, 4, 4, unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(1, 3, 10, 25)),

    g.timeseriesPanel(
      10,
      'CPU Saturation by Mode',
      [
        {
          expr: '100 * sum by (mode) (rate(node_cpu_seconds_total{job="node",mode!="idle"}[' + rateWindow + '])) / ' + cpuCores,
          legend: '{{mode}}',
        },
      ],
      0, 5, 8, 7,
      unit='percent',
      fillOpacity=30,
      gradientMode='opacity',
      stackingMode='normal',
      thresholds=g.greenYellowRed(70, 90),
      thresholdsStyle='line',
      overrides=[
        g.overrideByName('user', [g.propColor(c.teal), g.propFillOpacity(34)]),
        g.overrideByName('system', [g.propColor(c.blue), g.propFillOpacity(26)]),
        g.overrideByName('iowait', [g.propColor(c.peach), g.propFillOpacity(34), g.propLineWidth(2)]),
        g.overrideByName('irq', [g.propColor(c.yellow), g.propFillOpacity(18)]),
        g.overrideByName('softirq', [g.propColor(c.mauve), g.propFillOpacity(18)]),
        g.overrideByName('nice', [g.propColor(c.sky), g.propFillOpacity(12)]),
        g.overrideByName('steal', [g.propColor(c.red), g.propFillOpacity(28), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull'],
      colorMode='palette-classic'
    ),

    g.timeseriesPanel(
      11,
      'Memory Shape',
      [
        { expr: 'node_memory_MemTotal_bytes{job="node"} - node_memory_MemAvailable_bytes{job="node"}', legend: 'Used' },
        { expr: 'node_memory_MemAvailable_bytes{job="node"}', legend: 'Available' },
        { expr: 'node_memory_Cached_bytes{job="node"} + node_memory_Buffers_bytes{job="node"}', legend: 'Cache+Buffers' },
      ],
      8, 5, 8, 7,
      unit='bytes',
      fillOpacity=28,
      gradientMode='opacity',
      stackingMode='normal',
      overrides=[
        g.overrideByName('Used', [g.propColor(c.blue), g.propLineWidth(2)]),
        g.overrideByName('Available', [g.propColor(c.green), g.propFillOpacity(12)]),
        g.overrideByName('Cache+Buffers', [g.propColor(c.teal), g.propFillOpacity(18)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull'],
      colorMode='palette-classic'
    ),

    g.timeseriesPanel(
      12,
      'Load Envelope',
      [
        { expr: 'node_load1{job="node"}', legend: '1m' },
        { expr: 'node_load5{job="node"}', legend: '5m' },
        { expr: 'node_load15{job="node"}', legend: '15m' },
        { expr: cpuCores, legend: 'cores' },
      ],
      16, 5, 8, 7,
      unit='short',
      fillOpacity=12,
      gradientMode='none',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(4, 8),
      overrides=[
        g.overrideByName('1m', [g.propColor(c.teal), g.propLineWidth(2), g.propFillOpacity(18)]),
        g.overrideByName('5m', [g.propColor(c.blue), g.propLineWidth(2)]),
        g.overrideByName('15m', [g.propColor(c.lavender)]),
        g.overrideByName('cores', [g.propColor(c.red), g.propLineWidth(2), g.propLineStyle({ fill: 'dash' })]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.rowPanel(20, 'Pressure And Thermals', 12),

    g.barGaugePanel(
      21,
      'PSI Avg10',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'Memory' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
      ],
      0, 13, 5, 6,
      unit='percent',
      min=0,
      max=100,
      thresholds=g.fiveStep(1, 3, 10, 25),
      orientation='horizontal',
      displayMode='basic',
      overrides=[
        g.overrideByName('CPU', [g.propColor(c.teal)]),
        g.overrideByName('Memory', [g.propColor(c.mauve)]),
        g.overrideByName('IO', [g.propColor(c.peach)]),
      ]
    ),

    g.timeseriesPanel(
      22,
      'Pressure Timeline',
      [
        { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
        { expr: 'nix_pressure_mem_some_avg10', legend: 'Memory' },
        { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
      ],
      5, 13, 7, 6,
      unit='percent',
      fillOpacity=24,
      gradientMode='opacity',
      thresholdsStyle='line',
      thresholds=g.fiveStep(1, 3, 10, 25),
      overrides=[
        g.overrideByName('CPU', [g.propColor(c.teal), g.propLineWidth(2)]),
        g.overrideByName('Memory', [g.propColor(c.mauve), g.propLineWidth(2)]),
        g.overrideByName('IO', [g.propColor(c.peach), g.propLineWidth(2)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.timeseriesPanel(
      23,
      'Thermal Sensors',
      [
        { expr: 'node_hwmon_temp_celsius{job="node"}', legend: '{{chip}} {{sensor}}' },
        { expr: 'node_thermal_zone_temp{job="node"}', legend: '{{type}}' },
      ],
      12, 13, 7, 6,
      unit='celsius',
      fillOpacity=6,
      gradientMode='none',
      thresholdsStyle='line',
      thresholds=g.greenYellowRed(70, 85),
      overrides=[
        g.overrideByRegex('.*Package.*|.*Tctl.*|.*CPU.*', [g.propColor(c.peach), g.propLineWidth(2)]),
        g.overrideByRegex('.*NVME.*|.*Composite.*', [g.propColor(c.sky)]),
        g.overrideByRegex('.*thermal.*|.*x86_pkg_temp.*', [g.propColor(c.yellow)]),
        hiddenTimeAxis,
      ],
      legendPlacement='right',
      legendCalcs=['lastNotNull', 'max']
    ),

    g.timeseriesPanel(
      24,
      'Scheduler Pulse',
      [
        { expr: 'node_procs_running{job="node"}', legend: 'running' },
        { expr: 'node_procs_blocked{job="node"}', legend: 'blocked' },
        { expr: 'rate(node_context_switches_total{job="node"}[' + rateWindow + '])', legend: 'ctx/s' },
      ],
      19, 13, 5, 6,
      unit='short',
      fillOpacity=14,
      gradientMode='opacity',
      overrides=[
        g.overrideByName('running', [g.propColor(c.teal), g.propLineWidth(2)]),
        g.overrideByName('blocked', [g.propColor(c.red), g.propLineWidth(2)]),
        g.overrideByName('ctx/s', [g.propColor(c.blue), g.propAxisPlacement('right')]),
        hiddenTimeAxis,
      ],
      legendDisplayMode='list',
      legendPlacement='bottom',
      legendCalcs=['lastNotNull'],
      showLegend=true
    ),
  ],
}
