local g = import 'lib/dashboard.libsonnet';
local c = g.colors.theme;
local palette = g.colors.series;

local railW = 5;
local graphX = railW;
local graphW = 24 - railW;
local graphH = 9;
local counterH = 5;
local summaryH = 12;

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
local window = '$window';
local storeGrowth = 'deriv(nix_store_bytes[' + window + '])';
local closureGrowth = 'deriv(nix_closure_bytes[' + window + '])';
local closureRatio = 'nix_closure_bytes / clamp_min(nix_store_bytes, 1)';
local topClosureExpr = 'nix_closure_top_bytes or on() (label_replace(label_replace(absent(nix_closure_top_bytes), "rank", "0", "", ".*"), "path", "nix-metrics pending", "", ".*") * 0)';

local hiddenTimeAxis = {
  matcher: { id: 'byType', options: 'time' },
  properties: [g.propAxisPlacement('hidden')],
};

local railGauge(title, expr, unit='short', decimals=1, thresholds=null, min=0, max=100, datasource='Prometheus') =
  {
    id: 0,
    gridPos: { x: 0, y: 0, w: railW, h: counterH },
    type: 'gauge',
    title: title,
    pluginVersion: '13.0.0',
    datasource: g.datasourceRef(datasource),
    targets: if datasource == 'Loki' then [g.lokiTarget(expr)] else [g.prometheusTarget(expr, title)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      showThresholdLabels: false,
      showThresholdMarkers: true,
      sparkline: true,
      text: {},
      textMode: 'value',
    },
    fieldConfig: {
      defaults:
        {
          color: { mode: 'thresholds' },
          unit: unit,
          decimals: decimals,
          min: min,
          max: max,
          thresholds: if thresholds == null then g.seaglassScale(70, 90) else thresholds,
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
    justifyMode='center',
    textMode='value'
  );

local asRailPanel(panel, id, y) =
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
  const palette = ['#94e2d5', '#5d9ae1', '#b48efa', '#f5c2e7', '#73d9f7', '#a56c89', '#8df4ec', '#6aa6ff'];
  const text = '#f6fbff';
  const muted = '#96cbd2';
  const grid = '#202b60';
  const base = '#050513';
  const surface = '#0e184a';
  const bulls = palette[0];
  const bears = palette[3];
  const secondary = palette[4];
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

local systemSummary =
  g.textPanel(
    0,
    'System Summary',
    |||
      Small local observability stack for NixOS health, rebuilds, pressure, logs, and desktop signals.

      | Component | Endpoint | Role |
      | --- | --- | --- |
      | ![Prometheus](https://img.shields.io/badge/Prometheus-metrics-b48efa?style=flat-square&logo=prometheus&logoColor=white&labelColor=101216) | `localhost:9090` | Metrics TSDB and query engine |
      | ![Node Exporter](https://img.shields.io/badge/Node_Exporter-host-70efe5?style=flat-square&logo=nixos&logoColor=white&labelColor=101216) | `localhost:9100` | Host metrics plus textfile collector |
      | ![Loki](https://img.shields.io/badge/Loki-logs-8df4ec?style=flat-square&logo=grafana&logoColor=white&labelColor=101216) | `localhost:3100` | Centralized logs |
      | ![Promtail](https://img.shields.io/badge/Promtail-journald-f6fbff?style=flat-square&logo=grafana&logoColor=white&labelColor=101216) | `systemd service` | Journald scraping and labeling |
      | ![Grafana](https://img.shields.io/badge/Grafana-ui-f6fbff?style=flat-square&logo=grafana&logoColor=white&labelColor=101216) | `localhost:3000` | Dashboards and correlation UI |

      [GitHub](https://github.com/RomeoCavazza/setup-os) · [Observability wiki](https://github.com/RomeoCavazza/setup-os/wiki/Observability-and-Metrics)
|||,
    0, 0, railW, summaryH
  );

local cpuSaturation =
  g.timeseriesPanel(
    0,
    'CPU Utilization by Mode',
    [
      {
        expr: '100 * sum by (mode) (rate(node_cpu_seconds_total{job="node",mode!="idle"}[' + rateWindow + '])) / ' + cpuCores,
        legend: '{{mode}}',
      },
    ],
    graphX, 0, graphW, graphH,
    unit='percent',
    fillOpacity=12,
    gradientMode='opacity',
    stackingMode='normal',
    thresholds=g.greenYellowRed(70, 90),
    thresholdsStyle='line',
    overrides=[
      g.overrideByName('user', [g.propColor(c.cyan), g.propFillOpacity(12)]),
      g.overrideByName('system', [g.propColor(c.blue), g.propFillOpacity(10)]),
      g.overrideByName('iowait', [g.propColor(c.lavender), g.propFillOpacity(14), g.propLineWidth(2)]),
      g.overrideByName('irq', [g.propColor(c.sky), g.propFillOpacity(7)]),
      g.overrideByName('softirq', [g.propColor(c.pink), g.propFillOpacity(7)]),
      g.overrideByName('nice', [g.propColor(c.teal), g.propFillOpacity(5)]),
      g.overrideByName('steal', [g.propColor(c.mauve), g.propFillOpacity(10), g.propLineWidth(2)]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull']
  );

local memoryShape =
  g.timeseriesPanel(
    0,
    'Memory Usage Breakdown',
    [
      { expr: 'node_memory_MemTotal_bytes{job="node"} - node_memory_MemAvailable_bytes{job="node"}', legend: 'Used' },
      { expr: 'node_memory_MemAvailable_bytes{job="node"}', legend: 'Available' },
      { expr: 'node_memory_Cached_bytes{job="node"} + node_memory_Buffers_bytes{job="node"}', legend: 'Cache+Buffers' },
    ],
    graphX, 0, graphW, graphH,
    unit='bytes',
    fillOpacity=10,
    gradientMode='opacity',
    stackingMode='normal',
    overrides=[
      g.overrideByName('Used', [g.propColor(c.blue), g.propLineWidth(2)]),
      g.overrideByName('Available', [g.propColor(c.cyan), g.propFillOpacity(6)]),
      g.overrideByName('Cache+Buffers', [g.propColor(c.lavender), g.propFillOpacity(8)]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull']
  );

local loadEnvelope =
  g.timeseriesPanel(
    0,
    'Load Average vs CPU Capacity',
    [
      { expr: 'node_load1{job="node"}', legend: '1m' },
      { expr: 'node_load5{job="node"}', legend: '5m' },
      { expr: 'node_load15{job="node"}', legend: '15m' },
      { expr: cpuCores, legend: 'cores' },
    ],
    graphX, 0, graphW, graphH,
    unit='short',
    fillOpacity=6,
    gradientMode='opacity',
    thresholdsStyle='line',
    thresholds=g.greenYellowRed(4, 8),
    overrides=[
      g.overrideByName('1m', [g.propColor(c.cyan), g.propLineWidth(2), g.propFillOpacity(7)]),
      g.overrideByName('5m', [g.propColor(c.blue), g.propLineWidth(2)]),
      g.overrideByName('15m', [g.propColor(c.lavender)]),
      g.overrideByName('cores', [g.propColor(c.pink), g.propLineWidth(2), g.propLineStyle({ fill: 'dash' })]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'max']
  );

local pressureHeatmap =
  echartsPanel(
    'Resource Pressure Heatmap',
    [
      g.prometheusTarget('nix_pressure_cpu_avg10', 'CPU', 'A'),
      g.prometheusTarget('nix_pressure_mem_some_avg10', 'Memory', 'B'),
      g.prometheusTarget('nix_pressure_io_some_avg10', 'IO', 'C'),
    ],
    echartsPrelude + |||
      const order = ['CPU', 'Memory', 'IO'];
      const heatmapData = [];
      const rawValues = [];
      const colorRamp = [
        { value: 0, color: [16, 18, 22] },
        { value: 16, color: [22, 26, 31] },
        { value: 32, color: [31, 38, 44] },
        { value: 50, color: [42, 62, 66] },
        { value: 68, color: [57, 123, 124] },
        { value: 84, color: [112, 239, 229] },
        { value: 100, color: [246, 251, 255] },
      ];

      function percentile(values, q) {
        const sorted = values
          .filter(value => Number.isFinite(value))
          .sort((a, b) => a - b);
        if (!sorted.length) return 1;
        const index = Math.min(sorted.length - 1, Math.max(0, Math.floor((sorted.length - 1) * q)));
        return sorted[index];
      }
      
      let times = new Set();
      frames.forEach(frame => {
        points(frame).forEach(pt => times.add(pt[0]));
      });
      const sortedTimes = Array.from(times).sort((a,b) => a - b);
      const fallbackNow = Date.now();
      const xMin = sortedTimes[0] || fallbackNow - 60 * 60 * 1000;
      const xMax = sortedTimes[sortedTimes.length - 1] || fallbackNow;

      frames.forEach(frame => {
        points(frame).forEach(pt => rawValues.push(Math.max(0, Number(pt[1]) || 0)));
      });
      const visualMax = Math.max(0.1, percentile(rawValues, 0.98));
      const logMax = Math.log1p(visualMax);
      const shadeValue = (value) => Math.min(100, (Math.log1p(Math.max(0, value)) / logMax) * 100);

      function smoothPoints(framePoints) {
        const radius = Math.min(6, Math.max(2, Math.round(framePoints.length / 120)));
        return framePoints.map((pt, index) => {
          let total = 0;
          let weight = 0;
          for (let offset = -radius; offset <= radius; offset += 1) {
            const other = framePoints[index + offset];
            if (!other) continue;
            const currentWeight = Math.exp(-(offset * offset) / (2 * radius));
            total += other.shade * currentWeight;
            weight += currentWeight;
          }
          return {
            time: pt.time,
            raw: pt.raw,
            shade: weight ? total / weight : pt.shade,
          };
        });
      }

      function hex(channel) {
        return Math.round(channel).toString(16).padStart(2, '0');
      }

      function rgb(values) {
        return `#${hex(values[0])}${hex(values[1])}${hex(values[2])}`;
      }

      function mix(left, right, amount) {
        return [
          left[0] + (right[0] - left[0]) * amount,
          left[1] + (right[1] - left[1]) * amount,
          left[2] + (right[2] - left[2]) * amount,
        ];
      }

      function colorFor(value) {
        const bounded = Math.max(0, Math.min(100, value));
        for (let index = 1; index < colorRamp.length; index += 1) {
          const left = colorRamp[index - 1];
          const right = colorRamp[index];
          if (bounded <= right.value) {
            const span = Math.max(1, right.value - left.value);
            return rgb(mix(left.color, right.color, (bounded - left.value) / span));
          }
        }
        return rgb(colorRamp[colorRamp.length - 1].color);
      }
      
      const refMap = { 'A': 0, 'B': 1, 'C': 2 };
      frames.forEach(frame => {
        let yIndex = refMap[frame.refId];
        if (yIndex === undefined) yIndex = 0;

        const framePoints = points(frame)
          .map(pt => {
            const raw = Math.max(0, Number(pt[1]) || 0);
            return { time: pt[0], raw: raw, shade: shadeValue(raw) };
          })
          .sort((a, b) => a.time - b.time);

        smoothPoints(framePoints).forEach((pt, index, smoothedPoints) => {
          const next = smoothedPoints[index + 1];
          if (!next) return;
          heatmapData.push([pt.time, yIndex, pt.raw, pt.shade, next.time, next.raw, next.shade]);
        });
      });

      return {
        grid: { top: 0, bottom: 24, left: 60, right: 20 },
        xAxis: {
          type: 'time',
          min: xMin,
          max: xMax,
          splitLine: { show: false },
          axisLine: { show: false },
          axisTick: { show: false },
          axisLabel: {
            color: muted,
            formatter: (value) => {
              const d = new Date(value);
              return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
            }
          }
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
          type: 'custom',
          renderItem: function (params, api) {
            const startValue = api.value(0);
            const yValue = api.value(1);
            const endValue = api.value(4);
            const start = api.coord([startValue, yValue]);
            const end = api.coord([endValue, yValue]);
            const rowHeight = api.size([0, 1])[1] || 32;
            const gap = 8;
            return {
              type: 'rect',
              shape: {
                x: start[0],
                y: start[1] - rowHeight / 2 + gap / 2,
                width: Math.max(1, end[0] - start[0]),
                height: Math.max(1, rowHeight - gap)
              },
              style: {
                fill: {
                  type: 'linear',
                  x: 0,
                  y: 0,
                  x2: 1,
                  y2: 0,
                  colorStops: [
                    { offset: 0, color: colorFor(api.value(3)) },
                    { offset: 1, color: colorFor(api.value(6)) },
                  ],
                },
                opacity: 0.88
              }
            };
          },
          data: heatmapData,
          encode: { x: [0, 4], y: 1, tooltip: [2, 5] },
          emphasis: {
            itemStyle: { borderColor: text, borderWidth: 1 }
          }
        }],
        tooltip: {
          position: 'top',
          formatter: (params) => {
            const start = new Date(params.data[0]);
            const end = new Date(params.data[4]);
            const startTime = `${start.getHours().toString().padStart(2, '0')}:${start.getMinutes().toString().padStart(2, '0')}`;
            const endTime = `${end.getHours().toString().padStart(2, '0')}:${end.getMinutes().toString().padStart(2, '0')}`;
            return `${order[params.data[1]]} Pressure<br/><b>${params.data[2].toFixed(2)}% -> ${params.data[5].toFixed(2)}%</b><br/>${startTime} - ${endTime}`;
          }
        }
      };
    |||
  );

local pressureTimeline =
  g.timeseriesPanel(
    0,
    'Resource Pressure Timeline',
    [
      { expr: 'nix_pressure_cpu_avg10', legend: 'CPU' },
      { expr: 'nix_pressure_mem_some_avg10', legend: 'Memory' },
      { expr: 'nix_pressure_io_some_avg10', legend: 'IO' },
    ],
    graphX, 0, graphW, graphH,
    unit='percent',
    fillOpacity=9,
    gradientMode='opacity',
    thresholdsStyle='line',
    thresholds=g.fiveStep(1, 3, 10, 25),
    overrides=[
      g.overrideByName('CPU', [g.propColor(c.cyan), g.propLineWidth(2)]),
      g.overrideByName('Memory', [g.propColor(c.pink), g.propLineWidth(2)]),
      g.overrideByName('IO', [g.propColor(c.lavender), g.propLineWidth(2)]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'max']
  );

local thermalSensors =
  g.timeseriesPanel(
    0,
    'Temperature Sensors',
    [
      { expr: 'node_hwmon_temp_celsius{job="node"}', legend: '{{chip}} {{sensor}}' },
      { expr: 'node_thermal_zone_temp{job="node"}', legend: '{{type}}' },
    ],
    graphX, 0, graphW, graphH,
    unit='celsius',
    fillOpacity=4,
    gradientMode='opacity',
    thresholdsStyle='line',
    thresholds=g.greenYellowRed(70, 85),
    overrides=[
      g.overrideByRegex('.*Package.*|.*Tctl.*|.*CPU.*', [g.propColor(c.pink), g.propLineWidth(2)]),
      g.overrideByRegex('.*NVME.*|.*Composite.*', [g.propColor(c.cyan)]),
      g.overrideByRegex('.*thermal.*|.*x86_pkg_temp.*', [g.propColor(c.lavender)]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'max']
  );

local schedulerPulse =
  g.timeseriesPanel(
    0,
    'Process Scheduler Activity',
    [
      { expr: 'node_procs_running{job="node"}', legend: 'running' },
      { expr: 'node_procs_blocked{job="node"}', legend: 'blocked' },
      { expr: 'rate(node_context_switches_total{job="node"}[' + rateWindow + '])', legend: 'ctx/s' },
    ],
    graphX, 0, graphW, graphH,
    unit='none',
    fillOpacity=6,
    gradientMode='opacity',
    overrides=[
      g.overrideByName('running', [g.propColor(c.cyan), g.propLineWidth(2)]),
      g.overrideByName('blocked', [g.propColor(c.pink), g.propLineWidth(2)]),
      g.overrideByName('ctx/s', [g.propColor(c.blue), g.propAxisPlacement('right'), g.propUnit('ops')]),
      hiddenTimeAxis,
    ],
    legendDisplayMode='table',
    legendPlacement='right',
    legendCalcs=['lastNotNull'],
    showLegend=true
  );

local storeLifecycle =
  g.timeseriesPanel(
    0,
    'Nix Store Growth',
    [
      { expr: storeGrowth, legend: 'store growth' },
      { expr: closureGrowth, legend: 'closure growth' },
      { expr: 'nix_generation', legend: 'current generation' },
      { expr: 'nix_generations_count', legend: 'retained generations' },
    ],
    graphX, 0, graphW, graphH,
    unit='Bps',
    overrides=[
      {
        matcher: { id: 'byName', options: 'store growth' },
        properties: [g.propColor(c.blue), g.propDrawStyle('lines'), g.propFillOpacity(7), { id: 'custom.lineInterpolation', value: 'smooth' }],
      },
      {
        matcher: { id: 'byName', options: 'closure growth' },
        properties: [g.propColor(c.cyan), g.propDrawStyle('lines'), g.propFillOpacity(7), { id: 'custom.lineInterpolation', value: 'smooth' }],
      },
      g.overrideByName('current generation', [g.propColor(c.lavender), g.propLineWidth(2), g.propAxisPlacement('right'), g.propUnit('none')]),
      g.overrideByName('retained generations', [g.propColor(c.pink), g.propLineWidth(2), g.propAxisPlacement('right'), g.propUnit('none')]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'max']
  );

local rebuildActivityCalendar =
  echartsPanel(
    'Rebuild Activity',
    [g.prometheusTarget('count_over_time(nix_rebuild_success[1d])', 'rebuilds', 'A')],
    echartsPrelude + |||
      const frame = frames[0];
      const data = points(frame);
      const year = new Date().getFullYear();

      return {
        tooltip: {
          position: 'top',
          formatter: (p) => `${p.data[0]}: ${p.data[1]} rebuilds`
        },
        visualMap: {
          min: 1,
          max: 12,
          show: false,
          inRange: {
            color: [base, surface, palette[3], palette[1], palette[0]]
          },
          formatter: (v) => Math.floor(v)
        },
        calendar: {
          top: 30,
          left: 40,
          right: 40,
          bottom: 50,
          range: year.toString(),
          cellSize: ['auto', 13],
          splitLine: { show: false },
          itemStyle: {
            color: 'rgba(255,255,255,0.03)',
            borderWidth: 1.5,
            borderColor: base
          },
          yearLabel: { show: false },
          dayLabel: { color: muted, firstDay: 1, nameMap: 'en', margin: 5 },
          monthLabel: { color: text, fontWeight: 'bold', margin: 10 }
        },
        series: {
          type: 'heatmap',
          coordinateSystem: 'calendar',
          data: data.map(p => [
            new Date(p[0]).toISOString().split('T')[0],
            p[1]
          ])
        }
      };
    |||,
    datasource=g.prometheusDatasource
  );

local hardwareThermal =
  echartsPanel(
    'Thermal Sensor Detail',
    [
      g.prometheusTarget('node_hwmon_temp_celsius', '{{sensor}}', 'A'),
    ],
    echartsPrelude + |||
      // Filter for main CPU/Package sensors to avoid clutter
      const thermalPoints = frames.filter(f => {
        const lbls = labels(f);
        const name = lbls.sensor || lbls.chip || "";
        return name.includes('Package') || name.includes('Core') || name.includes('temp') || name.includes('input');
      }).map(f => ({
        name: labels(f).sensor || labels(f).chip || "Sensor",
        data: points(f)
      }));

      if (thermalPoints.length === 0) return { title: { text: "No Thermal Data", left: 'center', top: 'center', textStyle: { color: muted } } };

      return {
        color: palette,
        tooltip: { 
          trigger: 'axis',
          formatter: (params) => {
            const d = new Date(params[0].value[0]);
            const time = `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}:${d.getSeconds().toString().padStart(2, '0')}`;
            let res = `<b>${time}</b><br/>`;
            params.forEach(p => {
              res += `${p.marker} ${p.seriesName}: ${p.value[1].toFixed(1)}°C<br/>`;
            });
            return res;
          }
        },
        legend: {
          orient: 'vertical',
          top: 34,
          right: 10,
          bottom: 24,
          type: 'scroll',
          textStyle: { color: text, fontSize: 10 },
          pageIconColor: palette[0],
          pageTextStyle: { color: muted }
        },
        grid: { left: 40, right: 160, top: 40, bottom: 30 },
        xAxis: { 
          type: 'time', 
          axisLabel: { 
            color: muted,
            formatter: (v) => {
              const d = new Date(v);
              return `${d.getHours()}:${d.getMinutes().toString().padStart(2, '0')}`;
            }
          } 
        },
        yAxis: { type: 'value', axisLabel: { color: muted, formatter: '{value}°C' }, splitLine: { lineStyle: { color: grid, type: 'dashed' } } },
        series: thermalPoints.map((p, i) => {
          const isPackage = p.name.includes('Package');
          return {
            name: p.name,
            type: 'line',
            showSymbol: false,
            smooth: true,
            lineStyle: { 
              width: isPackage ? 3 : 1, 
              color: isPackage ? palette[0] : (palette[1 + (i % 3)]),
              opacity: isPackage ? 1 : 0.6
            },
            data: p.data
          };
        })
      };
    |||
  );

local gpuCockpit = {
  id: 0,
  title: 'NVIDIA GPU Metrics',
  type: 'timeseries',
  gridPos: { x: graphX, y: 0, w: graphW, h: graphH },
  datasource: g.prometheusDatasource,
  targets: [
    g.prometheusTarget('nvidia_smi_memory_used_bytes', 'VRAM Used', 'A'),
    g.prometheusTarget('nvidia_smi_memory_total_bytes', 'VRAM Total', 'B'),
    g.prometheusTarget('nvidia_smi_power_draw_watts', 'Power Draw', 'C'),
  ],
  options: {
    legend: { calcs: ['lastNotNull'], displayMode: 'table', placement: 'right', showLegend: true },
  },
  fieldConfig: {
    defaults: {
      unit: 'bytes',
      color: { mode: 'fixed', fixedColor: palette[0] },
      custom: { fillOpacity: 8, gradientMode: 'opacity', lineWidth: 2 },
    },
    overrides: [
      g.overrideByName('VRAM Used', [g.propUnit('bytes'), g.propColor(palette[0])]),
      g.overrideByName('VRAM Total', [g.propUnit('bytes'), g.propColor(palette[2])]),
      g.overrideByName('Power Draw', [g.propUnit('watt'), g.propColor(palette[1]), g.propAxisPlacement('right')]),
    ]
  }
};


local closureFlamegraph = {
  id: 0,
  title: 'Store Path Retention Flamegraph',
  type: 'flamegraph',
  gridPos: { x: 0, y: 0, w: g.graphW, h: g.graphH * 2 },
  datasource: g.datasourceRef('Prometheus'),
  targets: [
    g.prometheusTarget('nix_flamegraph', '', 'A', instant=true, format='table')
  ],
  transformations: [
    {
      id: 'labelsToFields',
      options: { mode: 'columns' }
    },
    {
      id: 'merge',
      options: {}
    },
    {
      id: 'sortBy',
      options: { fields: {}, sort: [{ field: 'rank', desc: false }] }
    },
    {
      id: 'calculateField',
      options: {
        mode: 'reduceRow',
        reduce: { reducer: 'sum' },
        alias: 'value',
        replaceFields: false,
      }
    },
    {
      id: 'organize',
      options: {
        excludeByName: { Time: true, rank: true, instance: true, job: true, __name__: true, nix_flamegraph: true, "Value #A": true, Value: true },
        renameByName: {},
        indexByName: { level: 0, value: 1, label: 2, "self": 3 },
      }
    },
    {
      id: 'convertFieldType',
      options: { fields: {}, conversions: [
        { targetField: 'level', destinationType: 'number' },
        { targetField: 'self', destinationType: 'number' }
      ]}
    }
  ],
  options: {
    displayMode: 'flamegraph',
  },
  fieldConfig: {
    defaults: {
      unit: 'decbytes',
    },
  },
};

local diskIoPerformance =
  g.timeseriesPanel(
    0,
    'Disk I/O Throughput and Latency',
    [
      { expr: 'rate(node_disk_read_bytes_total' + diskFilter + '[' + rateWindow + '])', legend: 'throughput read' },
      { expr: 'rate(node_disk_written_bytes_total' + diskFilter + '[' + rateWindow + '])', legend: 'throughput write' },
      { expr: readLatency, legend: 'latency read' },
      { expr: writeLatency, legend: 'latency write' },
    ],
    graphX, 0, graphW, graphH,
    unit='Bps',
    overrides=[
      g.overrideByName('throughput read', [g.propColor(c.cyan), g.propDrawStyle('bars'), g.propFillOpacity(4), g.propLineWidth(1)]),
      g.overrideByName('throughput write', [g.propColor(c.pink), g.propDrawStyle('bars'), g.propFillOpacity(4), g.propLineWidth(1)]),
      g.overrideByName('latency read', [g.propColor(c.blue), g.propLineWidth(2), g.propAxisPlacement('right'), g.propUnit('s')]),
      g.overrideByName('latency write', [g.propColor(c.lavender), g.propLineWidth(2), g.propAxisPlacement('right'), g.propUnit('s')]),
      hiddenTimeAxis,
    ],
    legendPlacement='right'
  );

local networkFaults =
  g.timeseriesPanel(
    0,
    'Network Error and Drop Rate',
    [
      { expr: 'rate(node_network_receive_errs_total' + netFilter + '[' + rateWindow + '])', legend: 'rx errors {{device}}' },
      { expr: 'rate(node_network_transmit_errs_total' + netFilter + '[' + rateWindow + '])', legend: 'tx errors {{device}}' },
      { expr: 'rate(node_network_receive_drop_total' + netFilter + '[' + rateWindow + '])', legend: 'rx drops {{device}}' },
      { expr: 'rate(node_network_transmit_drop_total' + netFilter + '[' + rateWindow + '])', legend: 'tx drops {{device}}' },
    ],
    graphX, 0, graphW, graphH,
    unit='ops',
    fillOpacity=7,
    gradientMode='opacity',
    thresholdsStyle='line',
    thresholds=g.greenYellowRed(0.01, 0.10),
    overrides=[
      g.overrideByRegex('rx errors .*', [g.propColor(c.pink), g.propLineWidth(2)]),
      g.overrideByRegex('tx errors .*', [g.propColor(c.maroon), g.propLineWidth(2)]),
      g.overrideByRegex('rx drops .*', [g.propColor(c.cyan)]),
      g.overrideByRegex('tx drops .*', [g.propColor(c.lavender)]),
      hiddenTimeAxis,
    ],
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'max']
  );

local journaldIncidentFeed =
  g.logsPanel(
    0,
    'Journal Incident Logs',
    journal + ' |~ "' + incidentPattern + '"',
    graphX, 0, graphW, graphH
  );

local incidentRiskRiver =
  echartsPanel(
    'Incident Risk Timeline',
    [
      g.prometheusTarget('max(' + diskReadSeverity + ')', 'read risk', 'A'),
      g.prometheusTarget('max(' + diskWriteSeverity + ')', 'write risk', 'B'),
      g.prometheusTarget('max(' + netSeverity + ')', 'net risk', 'C'),
      g.lokiRateTarget('{job="systemd-journal",component="system"}', incidentPattern, '$__interval', 'system log', 'D'),
      g.lokiRateTarget('{job="systemd-journal",component="build"}', incidentPattern, '$__interval', 'build log', 'E'),
      g.lokiRateTarget('{job="systemd-journal",component="display"}', incidentPattern, '$__interval', 'display log', 'F'),
    ],
    echartsPrelude + |||
      const styles = {
        'read risk': { color: palette[0], opacity: 0.12 },
        'write risk': { color: palette[3], opacity: 0.12 },
        'net risk': { color: palette[2], opacity: 0.12 },
        'system log': { color: palette[1], opacity: 0.18, width: 3 },
        'build log': { color: palette[4], opacity: 0.18, width: 3 },
        'display log': { color: palette[5], opacity: 0.18, width: 3 },
      };

      const series = frames.map((frame, index) => {
        const name = metricName(frame, frame.refId || `risk ${index + 1}`);
        const s = styles[name] || { color: palette[index % palette.length], opacity: 0.2 };
        return {
          name,
          type: 'line',
          smooth: true,
          symbol: 'none',
          stack: 'risk',
          areaStyle: { opacity: s.opacity },
          lineStyle: { width: s.width || 2 },
          itemStyle: { color: s.color },
          data: points(frame),
        };
      });

      return {
        color: palette,
        tooltip: { 
          trigger: 'axis', 
          axisPointer: { type: 'cross' },
          formatter: (params) => {
            const d = new Date(params[0].value[0]);
            const time = `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}:${d.getSeconds().toString().padStart(2, '0')}`;
            let res = `<b>${time}</b><br/>`;
            params.forEach(p => {
              res += `${p.marker} ${p.seriesName}: ${p.value[1].toFixed(2)}<br/>`;
            });
            return res;
          }
        },
        legend: { orient: 'vertical', right: 12, top: 32, textStyle: { color: text, fontSize: 10 } },
        grid: { left: 48, right: 150, top: 36, bottom: 32 },
        xAxis: { 
          type: 'time', 
          axisLabel: { 
            color: muted,
            formatter: (v) => {
              const d = new Date(v);
              return `${d.getHours()}:${d.getMinutes().toString().padStart(2, '0')}`;
            }
          }, 
          axisLine: { lineStyle: { color: grid } } 
        },
        yAxis: { type: 'value', min: 0, axisLabel: { color: muted }, splitLine: { lineStyle: { color: grid } } },
        series,
      };
|||,
    datasource=g.mixedDatasource
  );

local pulseCounters = [
  railSpark('Uptime', 'time() - node_boot_time_seconds{job="node"}', unit='s', decimals=0, thresholds=g.thresholds([{ color: c.blue, value: null }])) { options+: { graphMode: 'none' } },
  railGauge('CPU Utilization', cpuBusy, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(70, 90)),
  railGauge('Memory Used', memUsedPercent, unit='percent', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(75, 90)),
  railGauge('Load/Core', loadPerCore, unit='short', decimals=2, min=0, max=2, thresholds=g.greenYellowRed(0.8, 1.5)),
  railGauge('CPU Pressure', 'nix_pressure_cpu_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(2, 5, 15, 30)),
  railGauge('Memory Pressure', 'nix_pressure_mem_some_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(1, 3, 10, 25)),
  railGauge('Flake Lock Age', 'nix_flake_lock_age_seconds / 86400', unit='d', decimals=1, min=0, max=14, thresholds=g.greenYellowRed(3, 7)),
];

local pressureCounters = [
  railGauge('I/O Pressure', 'nix_pressure_io_some_avg10', unit='percent', decimals=2, min=0, max=100, thresholds=g.fiveStep(1, 3, 10, 25)),
  railGauge('Max Temperature', 'max({__name__=~"node_hwmon_temp_celsius|node_thermal_zone_temp",job="node"})', unit='celsius', decimals=1, min=0, max=100, thresholds=g.greenYellowRed(70, 85)),
  railSpark('Running', 'node_procs_running{job="node"}', unit='none', decimals=0, thresholds=g.thresholds([{ color: c.teal, value: null }])),
  railGauge('Blocked', 'node_procs_blocked{job="node"}', unit='none', decimals=0, min=0, max=5, thresholds=g.greenYellowRed(1, 3)),
  railSpark('Context Switches/s', 'sum(rate(node_context_switches_total{job="node"}[5m]))', unit='ops', decimals=0, thresholds=g.thresholds([{ color: c.blue, value: null }])),
];

local storeCounters = [
  railSpark('Store Used', 'nix_store_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.blue, value: null }])),
  railSpark('Store Free', 'nix_store_available_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.green, value: null }])),
  railGauge('Store Usage', 'nix_store_usage_ratio', unit='percentunit', decimals=1, min=0, max=1, thresholds=g.thresholds([{ color: c.blue, value: null }, { color: c.mauve, value: 0.75 }, { color: c.red, value: 0.95 }])),
  railSpark('Closure Size', 'nix_closure_bytes', unit='bytes', decimals=1, thresholds=g.thresholds([{ color: c.teal, value: null }])),
  railSpark('Closure Path Count', 'nix_closure_paths', unit='none', decimals=0, thresholds=g.thresholds([{ color: c.mauve, value: null }])),
  railGauge('Retained Generations', 'nix_generations_count', unit='none', decimals=0, min=0, max=12, thresholds=g.greenYellowRed(6, 10)),
];

local incidentCounters = [
  railSpark('Journal Incident Events', 'sum(count_over_time(' + journal + ' |~ "' + incidentPattern + '" [15m]))', datasource='Loki', unit='none', decimals=0, thresholds=g.greenYellowRed(3, 10)),
  railGauge('Last Rebuild Duration', 'nix_rebuild_duration_ms / 1000', unit='s', decimals=1, min=0, max=120, thresholds=g.greenYellowRed(30, 90)),
  railSpark('Max Read Latency', 'max(' + readLatency + ')', unit='s', decimals=4, thresholds=g.greenYellowRed(0.02, 0.10)),
  railSpark('Max Write Latency', 'max(' + writeLatency + ')', unit='s', decimals=4, thresholds=g.greenYellowRed(0.02, 0.10)),
  railGauge('Fullscreen Active', 'hypr_fullscreen_active', unit='bool', decimals=0, min=0, max=1, thresholds=g.thresholds([{color: c.blue, value:null}])),
  railSpark('Window Count', 'hypr_windows_total', unit='none', decimals=0, thresholds=g.thresholds([{color: c.teal, value:null}])),
];

local inspectionPanels = [
  cpuSaturation,
  memoryShape,
  loadEnvelope,
  pressureHeatmap,
  pressureTimeline,
  thermalSensors,
  schedulerPulse,
  storeLifecycle,
  rebuildActivityCalendar,
  hardwareThermal,
  gpuCockpit,
  closureFlamegraph,
  incidentRiskRiver,
  diskIoPerformance,
  networkFaults,
  journaldIncidentFeed,
];

local fullWidthPanel(panel, index) =
  panel {
    id: 4001 + index,
    gridPos: { x: graphX, y: index * graphH, w: graphW, h: graphH },
  };

g.dashboard(
  'NixOS System Overview',
  'nixos-compiled',
  '10s',
  'Canonical single-page overview of host performance, store health, rebuild activity, and incident diagnostics.',
  variables=[
    g.intervalVar('window', 'Growth window', ['3h', '12h', '24h', '7d'], '3h'),
  ],
) {
  timezone: 'browser',
  local pulseY = summaryH,
  local pressureY = pulseY + std.length(pulseCounters) * counterH,
  local storeY = pressureY + std.length(pressureCounters) * counterH,
  local incidentY = storeY + std.length(storeCounters) * counterH,
  local summaryPanel = systemSummary {
    id: 4000,
    gridPos: { x: 0, y: 0, w: railW, h: summaryH },
  },

  time: { from: 'now-3h', to: 'now' },
  panels:
    [summaryPanel]
    + counterStack(pulseCounters, 4101, pulseY)
    + counterStack(pressureCounters, 4201, pressureY)
    + counterStack(storeCounters, 4301, storeY)
    + counterStack(incidentCounters, 4401, incidentY)
    + std.mapWithIndex(function(index, panel) fullWidthPanel(panel, index), inspectionPanels),
}
