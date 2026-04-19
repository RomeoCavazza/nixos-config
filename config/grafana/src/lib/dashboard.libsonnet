// Grafonnet-style helpers, tuned to the Hyprland / Waybar / Rofi / Foot
// seaglass desktop. Graph colors stay in the wallpaper's cyan -> blue ->
// violet range; semantic states use brightness and hue shift instead of the
// default green / yellow / orange / red traffic-light palette.

// --------------------------------------------------------------------------
// PALETTE (Catppuccin Mocha, Waybar-aligned)
// --------------------------------------------------------------------------

local mocha = {
  // backgrounds (for thresholds on dark bg, rarely used as foreground)
  base: '#1e1e2e',
  mantle: '#181825',
  crust: '#11111b',
  surface0: '#313244',
  surface1: '#45475a',
  surface2: '#585b70',

  // text
  text: '#cdd6f4',
  subtext1: '#bac2de',
  subtext0: '#a6adc8',
  overlay2: '#9399b2',

  // vivid accents
  blue: '#89b4fa',      // Waybar primary — used for first-class series
  sapphire: '#74c7ec',
  sky: '#89dceb',
  teal: '#94e2d5',      // Waybar accent
  lavender: '#b4befe',
  mauve: '#cba6f7',
  pink: '#f5c2e7',
  flamingo: '#f2cdcd',

  // semantic
  green: '#a6e3a1',
  yellow: '#f9e2af',
  peach: '#fab387',
  maroon: '#eba0ac',
  red: '#f38ba8',
};

local seaglassTheme = mocha + {
  // background family sampled from docs/assets/background.png
  base: '#050513',
  mantle: '#0d0f2e',
  crust: '#050513',
  surface0: '#0e184a',
  surface1: '#202b60',
  surface2: '#2b529e',

  // text
  text: '#f6fbff',
  subtext1: '#d8f7fb',
  subtext0: '#96cbd2',
  overlay2: '#73d9f7',

  // accent family shared with rofi/waybar/hypr/foot
  teal: '#94e2d5',
  sky: '#73d9f7',
  sapphire: '#2f9de5',
  blue: '#5d9ae1',
  cyan: '#8df4ec',
  pink: '#f5c2e7',
  lavender: '#b48efa',
  mauve: '#a56c89',

  // cold semantic aliases, kept under familiar names for existing dashboards
  green: '#94e2d5',
  yellow: '#73d9f7',
  peach: '#b48efa',
  maroon: '#a56c89',
  red: '#f5c2e7',
};

local colors = {
  // Seaglass / Hyprchroma primary accents
  seaglass: {
    primary: '#94e2d5',    // Glowing Teal
    secondary: '#73d9f7',  // Sky Blue
    tertiary: '#5d9ae1',   // Sapphire Blue
    quaternary: '#b48efa', // Violet
    glow: '#8df4ec',       // Neon Cyan
  },

  // semantic
  ok: seaglassTheme.teal,
  warn: seaglassTheme.sky,
  hot: seaglassTheme.lavender,
  crit: seaglassTheme.pink,
  info: seaglassTheme.blue,
  accent: seaglassTheme.teal,

  // series palette: cold neon spread from the wallpaper, without traffic-light warmth.
  series: [
    seaglassTheme.teal,
    seaglassTheme.blue,
    seaglassTheme.lavender,
    seaglassTheme.pink,
    seaglassTheme.sky,
    seaglassTheme.mauve,
    seaglassTheme.cyan,
    '#6aa6ff',
  ],

  // full palette exposed so dashboards can reach for any Mocha tone
  mocha: mocha,
  theme: seaglassTheme,
};

// --------------------------------------------------------------------------
// COLOR MATH — hex interpolation for heat gradients (101 steps like Forecast)
// --------------------------------------------------------------------------

local strip = function(h) if std.startsWith(h, '#') then std.substr(h, 1, 6) else h;
local hexToRgb = function(h)
  local n = std.parseHex(strip(h));
  {
    r: std.floor(n / 65536) % 256,
    g: std.floor(n / 256) % 256,
    b: n % 256,
  };

local pad2 = function(s) if std.length(s) < 2 then '0' + s else s;
local intToHex2 = function(n)
  local v = if n < 0 then 0 else if n > 255 then 255 else std.floor(n + 0.5);
  pad2(std.format('%x', v));

local rgbToHex = function(r, g, b) '#' + intToHex2(r) + intToHex2(g) + intToHex2(b);
local lerp = function(a, b, t) a + (b - a) * t;
local lerpColor = function(h1, h2, t)
  local c1 = hexToRgb(h1);
  local c2 = hexToRgb(h2);
  rgbToHex(lerp(c1.r, c2.r, t), lerp(c1.g, c2.g, t), lerp(c1.b, c2.b, t));

{
  colors:: colors,

  prometheusDatasource:: { type: 'prometheus', uid: 'PBFA97CFB590B2093' },
  lokiDatasource:: { type: 'loki', uid: 'P8E80F9AEF21F6940' },
  mixedDatasource:: { type: 'datasource', uid: '-- Mixed --' },

  datasourceRef(ds)::
    if std.type(ds) == 'object' then ds
    else if ds == 'Loki' then $.lokiDatasource
    else if ds == 'Prometheus' then $.prometheusDatasource
    else ds,

  // High-End Hijack Utilities
  // Patch a specific panel by ID in a hijacked dashboard
  patchPanel(dashboard, panelId, overlay)::
    dashboard {
      panels: [
        if p.id == panelId then p + overlay else p
        for p in super.panels
      ],
    },

  // Map arbitrary template datasources to our local ones
  fixDatasources(dashboard)::
    dashboard {
      panels: [
        p + {
          datasource:
            if std.get(p, 'type') == 'logs' || std.get(p, 'datasource') == 'Loki' then
              { type: 'loki', uid: 'Loki' }
            else
              { type: 'prometheus', uid: 'Prometheus' }
        }
        for p in dashboard.panels
      ],
    },

  // Whitelist: only keep specific panel IDs and fix their datasources
  whitelist(dashboard, allowedIds)::
    self.fixDatasources(dashboard {
      panels: [
        p for p in dashboard.panels
        if std.count(allowedIds, p.id) > 0 || p.type == 'row'
      ],
    }),

  // Target override helper
  promTarget(expr, legend='', refId='A'):: {
    datasource: $.prometheusDatasource,
    expr: expr,
    legendFormat: legend,
    refId: refId,
  },

  // Public color helpers
  hexLerp(a, b, t):: lerpColor(a, b, t),

  // ---------------------------------------------------------------------
  // THRESHOLDS
  // ---------------------------------------------------------------------

  fixedColor(color):: {
    mode: 'fixed',
    fixedColor: color,
  },

  thresholds(steps):: {
    mode: 'absolute',
    steps: steps,
  },

  greenYellowRed(warn, crit):: $.thresholds([
    { color: colors.ok, value: null },
    { color: colors.warn, value: warn },
    { color: colors.crit, value: crit },
  ]),

  greenYellowRedHex(warn, crit):: $.greenYellowRed(warn, crit),

  // 5-color triad (ok / watch / warn / hot / crit) — more shades than the 3-step classic
  fiveStep(s1, s2, s3, s4):: $.thresholds([
    { color: colors.ok, value: null },
    { color: colors.accent, value: s1 },
    { color: colors.warn, value: s2 },
    { color: colors.hot, value: s3 },
    { color: colors.crit, value: s4 },
  ]),

  // Seaglass monochromatic thresholds (for a calm, one-piece look)
  seaglassScale(warn, crit):: $.thresholds([
    { color: colors.seaglass.primary, value: null },
    { color: colors.seaglass.tertiary, value: warn },
    { color: colors.crit, value: crit },
  ]),

  // BarGauge specific Seaglass scale (strictly cold)
  seaglassBarScale(warn, crit):: $.thresholds([
    { color: colors.seaglass.glow, value: null },
    { color: colors.seaglass.quaternary, value: warn },
    { color: colors.crit, value: crit },
  ]),

  // Continuous heat gradient — N threshold steps interpolated through 3 color stops.
  // Mirrors Forecast's 101-step temperature palette.
  heatGradient(startHex, midHex, endHex, minValue, maxValue, steps=101)::
    $.thresholds(
      std.mapWithIndex(
        function(i, _)
          local t = i / (steps - 1);
          local col = if t <= 0.5 then lerpColor(startHex, midHex, t * 2) else lerpColor(midHex, endHex, (t - 0.5) * 2);
          local v = minValue + (maxValue - minValue) * t;
          { color: col, value: if i == 0 then null else v },
        std.range(0, steps - 1)
      )
    ),

  // Cold pressure gradient: background blue -> electric cyan -> violet.
  mochaHeat(minValue, maxValue, steps=101)::
    $.heatGradient(seaglassTheme.blue, seaglassTheme.teal, seaglassTheme.lavender, minValue, maxValue, steps),

  // ---------------------------------------------------------------------
  // MAPPINGS
  // ---------------------------------------------------------------------

  noDataMapping:: {
    type: 'special',
    options: {
      match: 'null',
      result: { text: 'No data', color: seaglassTheme.overlay2, index: 0 },
    },
  },

  rangeMapping(from, to, text, color, index):: {
    type: 'range',
    options: {
      from: from,
      to: to,
      result: { text: text, color: color, index: index },
    },
  },

  valueMapping(value, text, color, index):: {
    type: 'value',
    options: {
      [std.toString(value)]: { text: text, color: color, index: index },
    },
  },

  // ---------------------------------------------------------------------
  // TARGETS
  // ---------------------------------------------------------------------

  prometheusTarget(expr, legendFormat, refId='A', instant=false, format=null):: {
    expr: expr,
    legendFormat: legendFormat,
    refId: refId,
    datasource: $.prometheusDatasource,
    editorMode: 'code',
  }
  + (if instant then { instant: true, range: false } else { instant: false, range: true })
  + (if format == null then {} else { format: format }),

  // Derivative of a gauge over a range (units per second).
  // Example: nix_store_bytes growth rate = deriv(nix_store_bytes[$window])
  derivTarget(metric, window, legend, refId='A'):: $.prometheusTarget(
    'deriv(' + metric + '[' + window + '])', legend, refId
  ),

  // Quantile-over-time of a gauge (for "p95 pressure over the last window").
  quantileOverTimeTarget(q, metric, window, legend, refId='A'):: $.prometheusTarget(
    'quantile_over_time(' + std.toString(q) + ', ' + metric + '[' + window + '])', legend, refId
  ),

  // Average-over-time (useful for "rebuild success rate over window").
  avgOverTimeTarget(metric, window, legend, refId='A'):: $.prometheusTarget(
    'avg_over_time(' + metric + '[' + window + '])', legend, refId
  ),

  lokiTarget(expr, refId='A'):: {
    expr: expr,
    refId: refId,
    datasource: $.lokiDatasource,
  },

  // Error-rate from a Loki log stream: count matches of a regex per window.
  lokiRateTarget(stream, pattern, window, legend, refId='A'):: {
    expr: 'sum(count_over_time(' + stream + ' |~ "' + pattern + '" [' + window + ']))',
    legendFormat: legend,
    refId: refId,
    datasource: $.lokiDatasource,
    queryType: 'range',
  },

  // ---------------------------------------------------------------------
  // VARIABLES & ANNOTATIONS
  // ---------------------------------------------------------------------

  intervalVar(name, label, options, default):: {
    name: name,
    label: label,
    type: 'interval',
    query: std.join(',', options),
    auto: false,
    current: { text: default, value: default, selected: true },
    options: std.map(function(o) { text: o, value: o, selected: o == default }, options),
    hide: 0,
    refresh: 2,
    skipUrlSync: false,
  },

  customVar(name, label, options, default):: {
    name: name,
    label: label,
    type: 'custom',
    query: std.join(',', options),
    current: { text: default, value: default, selected: true },
    options: std.map(function(o) { text: o, value: o, selected: o == default }, options),
    hide: 0,
    includeAll: false,
    multi: false,
    skipUrlSync: false,
  },

  queryVar(name, label, query, datasource=$.prometheusDatasource, includeAll=true, multi=false, regex=''):: {
    name: name,
    label: label,
    type: 'query',
    query: query,
    datasource: $.datasourceRef(datasource),
    refresh: 1,
    includeAll: includeAll,
    multi: multi,
    regex: regex,
    sort: 1,
    current: if includeAll then { text: 'All', value: '$__all', selected: true } else {},
    hide: 0,
    skipUrlSync: false,
  },

  annotationOnExpr(name, expr, color, iconColor=null):: {
    name: name,
    datasource: $.prometheusDatasource,
    enable: true,
    expr: expr,
    iconColor: if iconColor == null then color else iconColor,
    step: '',
    tagKeys: '',
    titleFormat: name,
    textFormat: '',
    useValueForTime: false,
    mappings: {},
    hide: false,
  },

  // ---------------------------------------------------------------------
  // OVERRIDES (per-series / per-column styling — the "pro" trick)
  // ---------------------------------------------------------------------

  overrideByName(name, properties):: {
    matcher: { id: 'byName', options: name },
    properties: properties,
  },

  overrideByRegex(pattern, properties):: {
    matcher: { id: 'byRegexp', options: pattern },
    properties: properties,
  },

  // Common property shorthand
  propColor(color)::          { id: 'color', value: { mode: 'fixed', fixedColor: color } },
  propUnit(unit)::            { id: 'unit', value: unit },
  propLineWidth(w)::          { id: 'custom.lineWidth', value: w },
  propFillOpacity(o)::        { id: 'custom.fillOpacity', value: o },
  propLineStyle(style)::      { id: 'custom.lineStyle', value: style },
  propAxisPlacement(p)::      { id: 'custom.axisPlacement', value: p },
  propAxisLabel(l)::          { id: 'custom.axisLabel', value: l },
  propDrawStyle(s)::          { id: 'custom.drawStyle', value: s },
  propGradientMode(m)::       { id: 'custom.gradientMode', value: m },
  propDisplayName(n)::        { id: 'displayName', value: n },
  propStacking(mode, group='A'):: { id: 'custom.stacking', value: { mode: mode, group: group } },
  propShowPoints(mode)::      { id: 'custom.showPoints', value: mode },
  propPointSize(s)::          { id: 'custom.pointSize', value: s },

  // Legacy helper retained for older call sites.
  overrideUnitByName(name, unit, axisPlacement=null, axisLabel=null, color=null,
                     fillOpacity=null, gradientMode=null, drawStyle=null,
                     lineWidth=null)::
    $.overrideByName(name,
      [{ id: 'unit', value: unit }]
      + (if axisPlacement == null then [] else [{ id: 'custom.axisPlacement', value: axisPlacement }])
      + (if axisLabel == null then [] else [{ id: 'custom.axisLabel', value: axisLabel }])
      + (if color == null then [] else [{ id: 'color', value: color }])
      + (if fillOpacity == null then [] else [{ id: 'custom.fillOpacity', value: fillOpacity }])
      + (if gradientMode == null then [] else [{ id: 'custom.gradientMode', value: gradientMode }])
      + (if drawStyle == null then [] else [{ id: 'custom.drawStyle', value: drawStyle }])
      + (if lineWidth == null then [] else [{ id: 'custom.lineWidth', value: lineWidth }])
    ),

  // ---------------------------------------------------------------------
  // DASHBOARD SHELL
  // ---------------------------------------------------------------------

  dashboard(title, uid, refresh, description, variables=[], annotations=[]):: {
    title: title,
    uid: uid,
    schemaVersion: 39,
    version: 1,
    editable: true,
    graphTooltip: 1,
    fiscalYearStartMonth: 0,
    liveNow: false,
    tags: ['nixos', 'local-observability'],
    timezone: 'browser',
    refresh: refresh,
    time: { from: 'now-6h', to: 'now' },
    timepicker: { refresh_intervals: ['30s', '1m', '5m', '15m'] },
    description: description,
    templating: { list: variables },
    annotations: {
      list: [
        {
          builtIn: 1,
          datasource: { type: 'grafana', uid: '-- Grafana --' },
          enable: true,
          hide: true,
          iconColor: seaglassTheme.overlay2,
          name: 'Annotations & Alerts',
          type: 'dashboard',
        },
      ] + annotations,
    },
    panels: [],
  },

  // ---------------------------------------------------------------------
  // PANELS
  // ---------------------------------------------------------------------

  textPanel(id, title, content, x, y, w, h=2):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'text',
    title: title,
    transparent: true,
    options: {
      mode: 'markdown',
      content: content,
      contentType: 'markdown',
    },
  },

  rowPanel(id, title, y):: {
    id: id,
    gridPos: { x: 0, y: y, w: 24, h: 1 },
    type: 'row',
    title: title,
    collapsed: false,
  },

  statPanel(
    id,
    title,
    expr,
    x,
    y,
    w,
    h=4,
    datasource='Prometheus',
    legend='value',
    unit=null,
    decimals=null,
    min=null,
    max=null,
    thresholds=null,
    mappings=null,
    colorMode='value',
    graphMode='area',
    textMode='auto',
    justifyMode='auto',
    overrides=[]
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'stat',
    title: title,
    datasource: $.datasourceRef(datasource),
    targets: if datasource == 'Loki' then [$.lokiTarget(expr)] else [$.prometheusTarget(expr, legend)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      orientation: 'auto',
      textMode: textMode,
      colorMode: colorMode,
      graphMode: graphMode,
      justifyMode: justifyMode,
      percentChangeColorMode: 'standard',
    },
    fieldConfig: {
      defaults:
        { color: { mode: 'thresholds' } }
        + (if unit == null then {} else { unit: unit })
        + (if decimals == null then {} else { decimals: decimals })
        + (if min == null then {} else { min: min })
        + (if max == null then {} else { max: max })
        + (if thresholds == null then {} else { thresholds: thresholds })
        + (if mappings == null then {} else { mappings: mappings }),
      overrides: overrides,
    },
  },

  gaugePanel(
    id,
    title,
    expr,
    legend,
    x,
    y,
    w,
    h=5,
    unit='percent',
    min=0,
    max=100,
    thresholds=null,
    labels=true
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'gauge',
    title: title,
    datasource: $.prometheusDatasource,
    targets: [$.prometheusTarget(expr, legend)],
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      showThresholdLabels: labels,
      showThresholdMarkers: true,
    },
    fieldConfig: {
      defaults: {
        unit: unit,
        min: min,
        max: max,
        thresholds: if thresholds == null then $.greenYellowRed(10, 30) else thresholds,
        color: { mode: 'thresholds' },
      },
      overrides: [],
    },
  },

  barGaugePanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=5,
    unit='percent',
    min=0,
    max=100,
    thresholds=null,
    orientation='horizontal',
    displayMode='gradient',
    valueMode='color',
    overrides=[]
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'bargauge',
    title: title,
    datasource: $.prometheusDatasource,
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(
          t.expr, t.legend,
          std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1)),
          instant=true
        ),
      targets
    ),
    options: {
      reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' },
      orientation: orientation,
      displayMode: displayMode,
      valueMode: valueMode,
      namePlacement: 'auto',
      showUnfilled: true,
      minVizWidth: 0,
      minVizHeight: 10,
      sizing: 'auto',
    },
    fieldConfig: {
      defaults:
        {
          unit: unit,
          min: min,
        }
        + (if max == null then {} else { max: max })
        + {
        thresholds: if thresholds == null then $.greenYellowRed(10, 30) else thresholds,
        color: { mode: 'thresholds' },
      },
      overrides: overrides,
    },
  },

  stateTimelinePanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=4,
    mappings=[],
    thresholds=null,
    unit='none',
    showLegend=true,
    legendPlacement='right',
    showValue='never',
    rowHeight=0.9
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'state-timeline',
    title: title,
    datasource: $.prometheusDatasource,
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(t.expr, t.legend, std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1))),
      targets
    ),
    options: {
      alignValue: 'center',
      mergeValues: true,
      rowHeight: rowHeight,
      showValue: showValue,
      legend: { displayMode: 'list', placement: legendPlacement, showLegend: showLegend },
      tooltip: { mode: 'multi', sort: 'desc' },
    },
    fieldConfig: {
      defaults: {
        unit: unit,
        color: { mode: 'thresholds' },
        thresholds: if thresholds == null then $.thresholds([
          { color: colors.ok, value: null },
          { color: colors.warn, value: 1 },
          { color: colors.crit, value: 2 },
        ]) else thresholds,
        mappings: mappings,
        custom: {
          fillOpacity: 80,
          lineWidth: 0,
          spanNulls: false,
          hideFrom: { legend: false, tooltip: false, viz: false },
        },
      },
      overrides: [],
    },
  },

  heatmapPanel(
    id,
    title,
    expr,
    x, y, w, h=8,
    unit='s',
    legend=''
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'heatmap',
    title: title,
    datasource: $.prometheusDatasource,
    targets: [$.prometheusTarget(expr, legend) + { format: 'time_series' }],
    options: {
      calculate: true,
      calculation: {
        xBuckets: { mode: 'auto' },
        yBuckets: { mode: 'count', value: 20 },
      },
      cellGap: 2,
      color: {
        mode: 'scheme',
        scheme: 'Blues',
        fill: seaglassTheme.blue,
        exponent: 0.5,
        steps: 128,
        reverse: false,
      },
      exemplars: { color: seaglassTheme.lavender },
      filterValues: { le: 1e-9 },
      legend: { show: true },
      rowsFrame: { layout: 'auto' },
      tooltip: { show: true, yHistogram: false },
      yAxis: { axisPlacement: 'left', reverse: false, unit: unit },
    },
    fieldConfig: { defaults: { custom: { scaleDistribution: { type: 'linear' } } }, overrides: [] },
  },

  tablePanel(
    id,
    title,
    targets,
    x, y, w, h=6,
    overrides=[],
    transformations=[]
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'table',
    title: title,
    datasource: $.prometheusDatasource,
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(
          t.expr, t.legend,
          std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1)),
          instant=true
        ) + { format: 'table' },
      targets
    ),
    transformations: transformations,
    options: {
      showHeader: true,
      cellHeight: 'sm',
      footer: { show: false, reducer: ['sum'], countRows: false, fields: '' },
    },
    fieldConfig: {
      defaults: {
        custom: {
          align: 'auto',
          cellOptions: { type: 'auto' },
          inspect: false,
        },
        color: { mode: 'thresholds' },
        thresholds: $.thresholds([{ color: seaglassTheme.text, value: null }]),
      },
      overrides: overrides,
    },
  },

  timeseriesPanel(
    id,
    title,
    targets,
    x,
    y,
    w,
    h=8,
    unit=null,
    axisLabel='',
    overrides=[],
    fillOpacity=8,
    gradientMode='opacity',
    thresholdsStyle='off',
    stackingMode='none',
    tooltip='multi',
    thresholds=null,
    drawStyle='line',
    lineInterpolation='smooth',
    lineWidth=2,
    pointSize=4,
    showPoints='never',
    barAlignment=0,
    legendDisplayMode='table',
    legendPlacement='right',
    legendCalcs=['lastNotNull', 'mean', 'max'],
    tooltipSort='desc',
    axisPlacement='auto',
    showLegend=true,
    colorMode='fixed'
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'timeseries',
    title: title,
    datasource: $.prometheusDatasource,
    targets: std.mapWithIndex(
      function(i, t)
        $.prometheusTarget(t.expr, t.legend, std.get(t, 'refId', std.substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', i, 1))),
      targets
    ),
    options: {
      legend: { calcs: legendCalcs, displayMode: legendDisplayMode, placement: legendPlacement, showLegend: showLegend },
      tooltip: { mode: tooltip, sort: tooltipSort },
    },
    fieldConfig: {
      defaults:
        {
          color: if colorMode == 'fixed' then { mode: 'fixed', fixedColor: colors.accent } else { mode: colorMode },
          custom: {
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: axisLabel,
            axisPlacement: axisPlacement,
            barAlignment: barAlignment,
            drawStyle: drawStyle,
            fillOpacity: fillOpacity,
            gradientMode: gradientMode,
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineInterpolation: lineInterpolation,
            lineWidth: lineWidth,
            pointSize: pointSize,
            scaleDistribution: { type: 'linear' },
            showPoints: showPoints,
            spanNulls: true,
            stacking: { group: 'A', mode: stackingMode },
            thresholdsStyle: { mode: thresholdsStyle },
          },
        }
        + (if unit == null then {} else { unit: unit })
        + (if thresholds == null then {} else { thresholds: thresholds }),
      overrides: overrides,
    },
  },

  // Timeseries that can mix prometheus + loki targets (pass targets as a list
  // of already-built target objects).
  multiTargetTimeseries(
    id, title, builtTargets, x, y, w, h=8,
    unit=null, axisLabel='', overrides=[], fillOpacity=8,
    gradientMode='opacity', thresholdsStyle='off', thresholds=null,
    legendDisplayMode='table', legendPlacement='right',
    legendCalcs=['lastNotNull', 'mean', 'max'], colorMode='fixed',
    lineWidth=2
  ):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'timeseries',
    title: title,
    datasource: $.mixedDatasource,
    targets: builtTargets,
    options: {
      legend: { calcs: legendCalcs, displayMode: legendDisplayMode, placement: legendPlacement, showLegend: true },
      tooltip: { mode: 'multi', sort: 'desc' },
    },
    fieldConfig: {
      defaults:
        {
          color: if colorMode == 'fixed' then { mode: 'fixed', fixedColor: colors.accent } else { mode: colorMode },
          custom: {
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: axisLabel,
            axisPlacement: 'auto',
            drawStyle: 'line',
            fillOpacity: fillOpacity,
            gradientMode: gradientMode,
            lineInterpolation: 'smooth',
            lineWidth: lineWidth,
            pointSize: 4,
            showPoints: 'never',
            spanNulls: true,
            stacking: { group: 'A', mode: 'none' },
            thresholdsStyle: { mode: thresholdsStyle },
          },
        }
        + (if unit == null then {} else { unit: unit })
        + (if thresholds == null then {} else { thresholds: thresholds }),
      overrides: overrides,
    },
  },

  logsPanel(id, title, expr, x, y, w, h):: {
    id: id,
    gridPos: { x: x, y: y, w: w, h: h },
    type: 'logs',
    title: title,
    datasource: $.lokiDatasource,
    targets: [$.lokiTarget(expr)],
    options: {
      showTime: true,
      showLabels: false,
      showCommonLabels: false,
      wrapLogMessage: true,
      sortOrder: 'Descending',
      dedupStrategy: 'none',
      prettifyLogMessage: false,
      enableLogDetails: true,
    },
  },
}
