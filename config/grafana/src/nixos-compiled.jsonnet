local g = import 'lib/dashboard.libsonnet';
local c = g.colors.mocha;

local engine = import 'nixos-engine.jsonnet';
local forge = import 'nixos-forge.jsonnet';
local blackBox = import 'nixos-black-box.jsonnet';

local railW = 4;
local graphX = railW;
local graphW = 24 - railW;
local graphH = 9;
local counterH = 4;

local rateWindow = '5m';
local cpuCores = 'scalar(count(count by (cpu) (node_cpu_seconds_total{job="node",mode="idle"})))';
local cpuBusy = '100 * (1 - avg(rate(node_cpu_seconds_total{job="node",mode="idle"}[' + rateWindow + '])))';
local memUsedPercent = '100 * (1 - node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"})';
local loadPerCore = 'node_load1{job="node"} / ' + cpuCores;
local diskFilter = '{job="node",device!~"^(loop|ram|zram|dm-).*"}';
local netFilter = '{job="node",device!="lo"}';
local readLatency = 'rate(node_disk_read_time_seconds_total' + diskFilter + '[' + rateWindow + ']) / clamp_min(rate(node_disk_reads_completed_total' + diskFilter + '[' + rateWindow + ']), 0.001)';
local writeLatency = 'rate(node_disk_write_time_seconds_total' + diskFilter + '[' + rateWindow + ']) / clamp_min(rate(node_disk_writes_completed_total' + diskFilter + '[' + rateWindow + ']), 0.001)';
local netFaults = 'sum by (device) (rate(node_network_receive_errs_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_transmit_errs_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_receive_drop_total' + netFilter + '[' + rateWindow + ']) + rate(node_network_transmit_drop_total' + netFilter + '[' + rateWindow + ']))';
local diskReadSeverity = '(' + readLatency + ' > bool 0.02) + (' + readLatency + ' > bool 0.10)';
local diskWriteSeverity = '(' + writeLatency + ' > bool 0.02) + (' + writeLatency + ' > bool 0.10)';
local netSeverity = '(' + netFaults + ' > bool 0) + (' + netFaults + ' > bool 0.1)';
local journal = '{job="systemd-journal"}';
local incidentPattern = '(?i)(error|failed|panic|oom|segfault|denied|timeout|i/o error)';
local closureRatio = 'nix_closure_bytes / clamp_min(nix_store_bytes, 1)';
local topClosureExpr = 'nix_closure_top_bytes or on() (label_replace(label_replace(absent(nix_closure_top_bytes), "rank", "0", "", ".*"), "path", "nix-metrics pending", "", ".*") * 0)';

local panelByTitle(dashboard, title) =
  std.filter(function(panel) std.get(panel, 'title', '') == title, dashboard.panels)[0];

local railGauge(title, expr, unit='short', decimals=1, thresholds=null, min=0, max=100, datasource='Prometheus') =
  {
    id: 0,
    gridPos: { x: 0, y: 0, w: railW, h: counterH },
    type: 'gauge',
    title: title,
    datasource: g.datasourceRef(datasource),
    targets: if datasource == 'Loki' then [g.lokiTarget(expr)] else [g.prometheusTarget(expr, title)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      showThresholdLabels: false,
      showThresholdMarkers: true,
      text: {},
      textMode: 'value',
      sparkline: { show: true, full: false },
      showSparkline: { show: true, full: false },
    },
    fieldConfig: {
      defaults:
        {
          color: { mode: 'thresholds' },
          unit: unit,
          decimals: decimals,
          min: min,
          max: max,
          thresholds: if thresholds == null then g.greenYellowRed(70, 90) else thresholds,
          custom: {
            sparkline: true,
            showSparkline: true
          }
        },
      overrides: [],
    },
  };

local railSpark(title, expr, unit='short', decimals=1, thresholds=null, datasource='Prometheus') =
  g.statPanel(
    0,
    title,
    expr,
    0,
    0,
    railW,
    counterH,
    unit=unit,
    decimals=decimals,
    datasource=datasource,
    thresholds=thresholds,
    colorMode='value',
    graphMode='area',
    textMode='value'
  );

local asRailPanel(panel, id, y) =
  if std.get(panel, 'type', '') == 'stat' then
    panel {
      id: id,
      gridPos: { x: 0, y: y, w: railW, h: counterH },
      options+: {
        colorMode: 'value',
        graphMode: 'area',
        justifyMode: 'center',
        textMode: 'value',
      },
    }
  else
    panel {
      id: id,
      gridPos: { x: 0, y: y, w: railW, h: counterH },
    };

local echartsOptions(code) = {
  renderer: 'canvas',
  map: 'none',
  editorMode: 'code',
  getOption: code,
  editor: { format: 'auto' },
  themeEditor: { name: 'default', config: '{}' },
  baidu: { key: '', callback: 'bmapReady' },
  gaode: { key: '', plugin: 'AMap.Scale,AMap.ToolBar' },
  google: { key: '', callback: 'gmapReady' },
  visualEditor: { dataset: [], series: [], code: '' },
};

local echartsPanel(title, targets, code, datasource=g.prometheusDatasource) = {
  id: 0,
  gridPos: { x: graphX, y: 0, w: graphW, h: graphH },
  type: 'volkovlabs-echarts-panel',
  title: title,
  datasource: datasource,
  targets: targets,
  options: echartsOptions(code),
  fieldConfig: { defaults: {}, overrides: [] },
  pluginVersion: '7.2.4',
};

local counterStack(panels, idOffset, yStart) =
  std.mapWithIndex(
    function(index, panel) asRailPanel(panel, idOffset + index, yStart + index * counterH),
    panels
  );

local echartsPrelude = |||
  const palette = ['#94e2d5', '#89b4fa', '#89dceb', '#74c7ec', '#b4befe', '#cba6f7', '#fab387', '#a6e3a1', '#f9e2af', '#f38ba8'];
  const text = '#cdd6f4';
  const muted = '#9399b2';
  const grid = '#313244';
  const frames = context.panel.data.series || [];

  function values(field) {
    const source = field && field.values;
    if (!source) {
      return [];
    }
    if (Array.isArray(source)) {
      return source;
    }
    if (source.buffer) {
      return Array.from(source.buffer);
    }
    if (typeof source.toArray === 'function') {
      return source.toArray();
    }
    return Array.from(source);
  }

  function numberField(frame) {
    return (frame.fields || []).find((field) => field.type === 'number');
  }

  function timeField(frame) {
    return (frame.fields || []).find((field) => field.type === 'time');
  }

  function lastNumber(frame) {
    const nums = values(numberField(frame));
    const value = nums.length ? nums[nums.length - 1] : 0;
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
  }

  function points(frame) {
    const times = values(timeField(frame));
    const nums = values(numberField(frame));
    return nums
      .map((value, index) => [times[index], Number(value) || 0])
      .filter((point) => point[0] !== undefined && point[0] !== null);
  }

  function labels(frame) {
    const field = numberField(frame);
    return (field && field.labels) || {};
  }

  function metricName(frame, fallback) {
    const labelSet = labels(frame);
    return String(labelSet.path || frame.name || frame.refId || fallback || '').replace(/^#\d+\s+/, '');
  }

  function lastByName(name) {
    const frame = frames.find((item) => metricName(item, item.refId).toLowerCase().includes(name.toLowerCase()));
    return frame ? lastNumber(frame) : 0;
  }

  function formatBytes(value) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    let n = Number(value) || 0;
    let unit = 0;
    while (n >= 1024 && unit < units.length - 1) {
      n /= 1024;
      unit += 1;
    }
    return `${n.toFixed(n >= 10 || unit === 0 ? 0 : 1)} ${units[unit]}`;
  }

  function shortPath(path) {
    const value = String(path || '');
    const slash = value.lastIndexOf('/');
    return slash >= 0 ? value.slice(slash + 1) : value;
  }
|||;

local pressureHeatmap =
  echartsPanel(
    'Pressure Heatmap',
    [
      g.prometheusTarget('nix_pressure_cpu_avg10', 'CPU', 'A'),
      g.prometheusTarget('nix_pressure_mem_some_avg10', 'Memory', 'B'),
      g.prometheusTarget('nix_pressure_io_some_avg10', 'IO', 'C'),
    ],
    echartsPrelude + |||
      const order = ['CPU', 'Memory', 'IO'];
      const heatmapData = [];
      
      let times = new Set();
      frames.forEach(frame => {
        points(frame).forEach(pt => times.add(pt[0]));
      });
      const sortedTimes = Array.from(times).sort((a,b) => a - b);
      
      const refMap = { 'A': 0, 'B': 1, 'C': 2 };
      frames.forEach(frame => {
        let yIndex = refMap[frame.refId];
        if (yIndex === undefined) yIndex = 0;
        
        points(frame).forEach(pt => {
          let xIndex = sortedTimes.indexOf(pt[0]);
          heatmapData.push([xIndex, yIndex, pt[1]]);
        });
      });

      return {
        grid: { top: 10, bottom: 24, left: 60, right: 20 },
        visualMap: {
          min: 0,
          max: 100,
          show: false,
          inRange: {
            color: ['#1e1e2e', palette[1], palette[6], palette[9]]
          }
        },
        xAxis: {
          type: 'category',
          data: sortedTimes.map(ts => {
             let d = new Date(ts);
             return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
          }),
          splitLine: { show: false },
          axisLine: { show: false },
          axisTick: { show: false },
          axisLabel: { color: muted, interval: Math.floor(sortedTimes.length / 8) }
        },
        yAxis: {
          type: 'category',
          data: order,
          splitLine: { show: false },
          axisLine: { show: false },
          axisTick: { show: false },
          axisLabel: { color: text, fontWeight: 'bold' }
        },
        series: [{
          type: 'heatmap',
          data: heatmapData,
          itemStyle: {
            borderRadius: 2,
            borderColor: '#1e1e2e',
            borderWidth: 1
          },
          emphasis: {
            itemStyle: { borderColor: text, borderWidth: 1 }
          }
        }],
        tooltip: {
          position: 'top',
          formatter: (params) => `${order[params.data[1]]} Pressure<br/><b>${params.data[2].toFixed(1)}%</b>`
        }
      };
    |||
  );

local capacityRadar =
  echartsPanel(
    'Capacity Radar',
    [
      g.prometheusTarget('nix_store_usage_ratio', 'Store Fill', 'A', instant=true),
      g.prometheusTarget('clamp_max(' + closureRatio + ', 1)', 'Closure Share', 'B', instant=true),
      g.prometheusTarget('clamp_max(nix_generations_count / 12, 1)', 'Generation Debt', 'C', instant=true),
    ],
    echartsPrelude + |||
      const order = ['Store Fill', 'Closure Share', 'Generation Debt'];
      const data = order.map((name) => Math.max(0, Math.min(1, lastByName(name))));

      return {
        color: palette,
        tooltip: {
          trigger: 'item',
          valueFormatter: (value) => `${(Number(value) * 100).toFixed(1)}%`,
        },
        radar: {
          center: ['50%', '53%'],
          radius: '72%',
          indicator: order.map((name) => ({ name, max: 1 })),
          splitNumber: 4,
          axisName: { color: text, fontSize: 13 },
          axisLine: { lineStyle: { color: grid } },
          splitLine: { lineStyle: { color: grid } },
          splitArea: { areaStyle: { color: ['rgba(137,180,250,0.12)', 'rgba(17,17,27,0.10)'] } },
        },
        series: [{
          type: 'radar',
          symbol: 'circle',
          symbolSize: 8,
          lineStyle: { width: 3, color: palette[1] },
          areaStyle: { opacity: 0.24, color: palette[1] },
          data: [{ name: 'capacity pressure', value: data }],
        }],
      };
|||
  );

local buildRunway =
  g.heatmapPanel(
    0,
    'Build Duration Heatmap',
    'nix_rebuild_duration_ms / 1000',
    0, 0, g.graphW, g.graphH,
    unit='s',
    legend='build duration'
  );

local closureFlamegraph = {
  id: 0,
  title: 'Nix Store Retention Map',
  type: 'flamegraph',
  gridPos: { x: 0, y: 0, w: g.graphW, h: g.graphH * 2 },
  datasource: g.datasourceRef('Prometheus'),
  targets: [
    g.prometheusTarget('nix_flamegraph', 'value', 'A', instant=true, format='time_series')
  ],
  transformations: [
    {
      id: 'labelsToFields',
      options: { mode: 'columns' }
    },
    {
      id: 'sortBy',
      options: { fields: {}, sort: [{ field: 'rank', desc: false }] }
    },
    {
      id: 'convertFieldType',
      options: { fields: {}, conversions: [
        { targetField: 'level', destinationType: 'number' },
        { targetField: 'self', destinationType: 'number' }
      ]}
    },
    {
      id: 'organize',
      options: {
        excludeByName: { Time: true, rank: true, instance: true, job: true, __name__: true },
        renameByName: { Value: 'value', 'Value #A': 'value', 'value': 'value', 'nix_flamegraph': 'value' },
        indexByName: {},
      }
    }
  ],
  options: {
    displayMode: 'both',
  }
};

local incidentRiskRiver =
  echartsPanel(
    'Incident Risk River',
    [
      g.prometheusTarget('max(' + diskReadSeverity + ')', 'read risk', 'A'),
      g.prometheusTarget('max(' + diskWriteSeverity + ')', 'write risk', 'B'),
      g.prometheusTarget('max(' + netSeverity + ')', 'net risk', 'C'),
      g.lokiRateTarget(journal, incidentPattern, '$__interval', 'journal incidents', 'D'),
    ],
    echartsPrelude + |||
      const series = frames.map((frame, index) => ({
        name: metricName(frame, frame.refId || `risk ${index + 1}`),
        type: 'line',
        smooth: true,
        symbol: 'none',
        stack: 'risk',
        areaStyle: { opacity: 0.22 },
        lineStyle: { width: 2 },
        itemStyle: { color: palette[index % palette.length] },
        data: points(frame),
      }));

      return {
        color: palette,
        tooltip: { trigger: 'axis', axisPointer: { type: 'cross' } },
        legend: { right: 12, top: 0, textStyle: { color: text } },
        grid: { left: 48, right: 28, top: 36, bottom: 32 },
        xAxis: { type: 'time', axisLabel: { color: muted }, axisLine: { lineStyle: { color: grid } } },
        yAxis: { type: 'value', min: 0, axisLabel: { color: muted }, splitLine: { lineStyle: { color: grid } } },
        series,
      };
|||,
    datasource=g.mixedDatasource
  );

local pulseCounters = [
  railSpark('Uptime', 'time() - node_boot_time_seconds{job="node"}', unit='s', decimals=0, thresholds=g.thresholds([{ color: c.blue, value: null }])),
  railGauge('CPU Busy', cpuBusy, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(70, 90)),
  railGauge('RAM Used', memUsedPercent, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(75, 90)),
  railGauge('Load/Core', loadPerCore, unit='short', decimals=2, min=0, max=2, thresholds=g.greenYellowRed(0.8, 1.5)),
  railGauge('CPU PSI', 'nix_pressure_cpu_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(2, 5, 15, 30)),
  railGauge('Memory PSI', 'nix_pressure_mem_some_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(1, 3, 10, 25)),
];

local pressureCounters = [
  railGauge('IO PSI', 'nix_pressure_io_some_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(1, 3, 10, 25)),
  railGauge('Max Temp', 'max({__name__=~"node_hwmon_temp_celsius|node_thermal_zone_temp",job="node"})', unit='celsius', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(70, 85)),
  railSpark('Running', 'node_procs_running{job="node"}', unit='none', decimals=0, thresholds=g.thresholds([{ color: c.teal, value: null }])),
  railGauge('Blocked', 'node_procs_blocked{job="node"}', unit='none', decimals=0, min=0, max=5, thresholds=g.greenYellowRed(1, 3)),
  railSpark('Ctx/s', 'sum(rate(node_context_switches_total{job="node"}[5m]))', unit='ops', decimals=0, thresholds=g.thresholds([{ color: c.blue, value: null }])),
];

local storeCounters = [
  railSpark('Store Used', 'nix_store_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.blue, value: null }])),
  railSpark('Store Free', 'nix_store_available_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.green, value: null }])),
  railGauge('Store Fill', 'nix_store_usage_ratio', unit='percentunit', decimals=1, min=0, max=1, thresholds=g.greenYellowRed(0.75, 0.9)),
  railSpark('Closure Size', 'nix_closure_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.teal, value: null }])),
  railSpark('Closure Paths', 'nix_closure_paths', unit='none', decimals=0, thresholds=g.thresholds([{ color: c.mauve, value: null }])),
  railGauge('Generations', 'nix_generations_count', unit='none', decimals=0, min=0, max=12, thresholds=g.greenYellowRed(6, 10)),
];

local incidentCounters = [
  railGauge('Journal Incidents', 'sum(count_over_time(' + journal + ' |~ "' + incidentPattern + '" [15m]))', datasource='Loki', unit='none', decimals=0, min=0, max=20, thresholds=g.greenYellowRed(3, 10)),
  railGauge('Build Log Faults', 'sum(count_over_time({job="systemd-journal",component="build"} |~ "' + incidentPattern + '" [15m]))', datasource='Loki', unit='none', decimals=0, min=0, max=8, thresholds=g.greenYellowRed(1, 4)),
  railGauge('Read Latency', 'max(' + readLatency + ')', unit='s', decimals=4, min=0, max=0.2, thresholds=g.greenYellowRed(0.02, 0.10)),
  railGauge('Write Latency', 'max(' + writeLatency + ')', unit='s', decimals=4, min=0, max=0.2, thresholds=g.greenYellowRed(0.02, 0.10)),
  railGauge('Net Faults/s', 'sum(' + netFaults + ')', unit='ops', decimals=3, min=0, max=0.2, thresholds=g.greenYellowRed(0.01, 0.10)),
  railGauge('Critical Units', 'sum(count_over_time({job="systemd-journal"} |= "Failed" [15m]))', datasource='Loki', unit='none', decimals=0, min=0, max=8, thresholds=g.greenYellowRed(1, 3)),
];

local inspectionPanels = [
  panelByTitle(engine, 'CPU Saturation by Mode'),
  panelByTitle(engine, 'Memory Shape'),
  panelByTitle(engine, 'Load Envelope'),
  pressureHeatmap,
  panelByTitle(engine, 'Pressure Timeline'),
  panelByTitle(engine, 'Thermal Sensors'),
  panelByTitle(engine, 'Scheduler Pulse'),
  capacityRadar,
  panelByTitle(forge, 'Store Footprint'),
  panelByTitle(forge, 'Growth Velocity'),
  buildRunway,
  panelByTitle(forge, 'Generation History'),
  panelByTitle(forge, 'Rebuild Cost'),
  closureFlamegraph,
  incidentRiskRiver,
  panelByTitle(blackBox, 'Disk Operation Latency'),
  panelByTitle(blackBox, 'Disk Throughput'),
  panelByTitle(blackBox, 'Network Faults'),
  panelByTitle(blackBox, 'Journal Semantic Events'),
  panelByTitle(blackBox, 'Journald Incident Feed'),
];

local fullWidthPanel(panel, index) =
  panel {
    id: 4001 + index,
    gridPos: { x: graphX, y: index * graphH, w: graphW, h: graphH },
  };

g.dashboard(
  'NixOS Compiled',
  'nixos-compiled',
  '10s',
  'Single-page experimental compilation of Engine, Forge, and Black Box.',
  variables=[
    g.intervalVar('window', 'Growth window', ['15m', '1h', '6h', '24h', '7d'], '6h'),
  ]
) {
  time: { from: 'now-24h', to: 'now' },
  panels:
    counterStack(pulseCounters, 4101, 0)
    + counterStack(pressureCounters, 4201, 27)
    + counterStack(storeCounters, 4301, 63)
    + counterStack(incidentCounters, 4401, 135)
    + std.mapWithIndex(function(index, panel) fullWidthPanel(panel, index), inspectionPanels),
}
